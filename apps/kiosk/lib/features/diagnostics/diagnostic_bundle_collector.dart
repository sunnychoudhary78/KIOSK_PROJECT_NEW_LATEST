import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/runtime/kiosk_runtime_paths.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_recorder.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_upload_queue.dart';

/// Builds and uploads a diagnostics zip (logs + upload-queue + recordings inventory).
class DiagnosticBundleCollector {
  DiagnosticBundleCollector({
    required ApiClient api,
    required SurveillanceRecorder recorder,
  })  : _api = api,
        _recorder = recorder;

  final ApiClient _api;
  final SurveillanceRecorder _recorder;

  Future<Map<String, dynamic>> collectAndUpload({
    required String deviceId,
    required String commandId,
  }) async {
    final workDir = await Directory.systemTemp.createTemp('skp_diag_');
    try {
      final zipPath = p.join(workDir.path, 'diagnostics.zip');
      final inventoryCount = await _buildZip(
        zipPath: zipPath,
        deviceId: deviceId,
      );
      final zipFile = File(zipPath);
      final bytes = await zipFile.length();

      final granted = await _api.post(
        '/devices/$deviceId/diagnostic-bundles/upload-url',
        body: {
          'commandId': commandId,
          'bytes': bytes,
          'contentType': 'application/zip',
        },
      );
      final bundleId = granted['bundleId']?.toString();
      final uploadUrl = granted['uploadUrl']?.toString();
      final objectKey = granted['objectKey']?.toString();
      if (bundleId == null ||
          bundleId.isEmpty ||
          uploadUrl == null ||
          uploadUrl.isEmpty) {
        throw ApiException(
          code: 'upload_url_failed',
          message: 'Missing diagnostics upload fields',
        );
      }

      await _api.putFileToUrl(
        url: uploadUrl,
        file: zipFile,
        contentType: 'application/zip',
        timeout: Duration(
          seconds: (bytes / (50 * 1024)).ceil().clamp(5 * 60, 15 * 60),
        ),
      );
      await _api.post('/devices/$deviceId/diagnostic-bundles/$bundleId/complete');

      AppLogger.info(
        'DIAGNOSTICS_BUNDLE_OK bundleId=$bundleId bytes=$bytes inventory=$inventoryCount',
      );
      return {
        'bundleId': bundleId,
        'bytes': bytes,
        'objectKey': objectKey ?? '',
        'inventoryCount': inventoryCount,
      };
    } finally {
      try {
        if (workDir.existsSync()) {
          workDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<int> _buildZip({
    required String zipPath,
    required String deviceId,
  }) async {
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    try {
      await _addLogFiles(encoder);
      final rootPath = await _recorder.getRootDir(deviceId);
      if (rootPath != null && rootPath.isNotEmpty) {
        final queueFile = File(p.join(rootPath, surveillanceQueueFileName));
        if (queueFile.existsSync()) {
          encoder.addFile(queueFile, surveillanceQueueFileName);
        }
        final inventory = await _buildInventory(rootPath: rootPath, queueFile: queueFile);
        final inventoryPath = p.join(p.dirname(zipPath), 'recordings-inventory.json');
        await File(inventoryPath).writeAsString(
          const JsonEncoder.withIndent('  ').convert(inventory),
        );
        encoder.addFile(File(inventoryPath), 'recordings-inventory.json');
        return (inventory['recordings'] as List?)?.length ?? 0;
      }
      final emptyInventory = {
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'root': null,
        'recordings': <Map<String, dynamic>>[],
      };
      final inventoryPath = p.join(p.dirname(zipPath), 'recordings-inventory.json');
      await File(inventoryPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(emptyInventory),
      );
      encoder.addFile(File(inventoryPath), 'recordings-inventory.json');
      return 0;
    } finally {
      encoder.close();
    }
  }

  Future<void> _addLogFiles(ZipFileEncoder encoder) async {
    final active = File(kioskAppLogPath);
    if (active.existsSync()) {
      encoder.addFile(active, 'app.log');
    }
    for (var i = 1; i <= AppLogger.maxRotatedFiles; i++) {
      final rotated = File('$kioskAppLogPath.$i');
      if (rotated.existsSync()) {
        encoder.addFile(rotated, 'app.log.$i');
      }
    }
  }

  Future<Map<String, dynamic>> _buildInventory({
    required String rootPath,
    required File queueFile,
  }) async {
    final byPath = <String, Map<String, dynamic>>{};
    SurveillanceUploadQueue? queue;
    if (queueFile.existsSync()) {
      queue = SurveillanceUploadQueue(queueFile: queueFile);
      await queue.load();
      for (final item in queue.items) {
        byPath[p.normalize(item.path)] = {
          'filename': item.filename,
          'path': item.path,
          'bytes': item.bytes,
          'recordedOn': item.recordedOn,
          'queueStatus': item.status,
          'lastError': item.lastError,
          'attempts': item.attempts,
          'segmentId': item.segmentId,
          'enqueuedAt': item.enqueuedAt.toUtc().toIso8601String(),
          'onDisk': false,
          'modifiedAt': null,
        };
      }
    }

    final root = Directory(rootPath);
    if (root.existsSync()) {
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        if (!isCompletedSegmentPath(entity.path) &&
            p.basename(entity.path).toLowerCase() != surveillanceInProgressName) {
          continue;
        }
        final normalized = p.normalize(entity.path);
        final stat = await entity.stat();
        final existing = byPath[normalized];
        byPath[normalized] = {
          'filename': p.basename(entity.path),
          'path': entity.path,
          'bytes': existing?['bytes'] ?? stat.size,
          'recordedOn':
              existing?['recordedOn'] ?? recordedOnFromPath(entity.path) ?? '',
          'queueStatus': existing?['queueStatus'] ??
              (p.basename(entity.path).toLowerCase() == surveillanceInProgressName
                  ? 'recording'
                  : 'on_disk_only'),
          'lastError': existing?['lastError'],
          'attempts': existing?['attempts'] ?? 0,
          'segmentId': existing?['segmentId'],
          'enqueuedAt': existing?['enqueuedAt'],
          'onDisk': true,
          'modifiedAt': stat.modified.toUtc().toIso8601String(),
        };
      }
    }

    final recordings = byPath.values.toList()
      ..sort((a, b) {
        final am = a['modifiedAt'] as String? ?? a['enqueuedAt'] as String? ?? '';
        final bm = b['modifiedAt'] as String? ?? b['enqueuedAt'] as String? ?? '';
        return bm.compareTo(am);
      });

    return {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'root': rootPath,
      'recordings': recordings,
    };
  }
}
