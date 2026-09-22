import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_recorder.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_upload_queue.dart';

abstract class SurveillanceUploadSink {
  Future<void> attach({required String deviceId});
  Future<void> enqueue({required String path, int? bytes});
  Future<void> detach();
}

class SurveillanceUploader implements SurveillanceUploadSink {
  SurveillanceUploader({
    required ApiClient api,
    required SurveillanceRecorder recorder,
    this.tickInterval = const Duration(seconds: 5),
    DateTime Function()? clock,
    Directory? rootOverride,
    SurveillanceUploadQueue? queue,
  })  : _api = api,
        _recorder = recorder,
        _clock = clock ?? DateTime.now,
        _rootOverride = rootOverride,
        _queueOverride = queue;

  final ApiClient _api;
  final SurveillanceRecorder _recorder;
  final Duration tickInterval;
  final DateTime Function() _clock;
  final Directory? _rootOverride;
  final SurveillanceUploadQueue? _queueOverride;

  SurveillanceUploadQueue? _queue;
  String? _deviceId;
  Timer? _timer;
  bool _tickInFlight = false;

  String? get deviceId => _deviceId;

  @override
  Future<void> attach({required String deviceId}) async {
    if (deviceId.isEmpty) {
      return;
    }
    if (_deviceId == deviceId && _queue != null) {
      return;
    }
    await detach();
    _deviceId = deviceId;
    final root = _rootOverride ?? await _resolveRoot(deviceId);
    if (_queueOverride == null && root == null) {
      _deviceId = null;
      return;
    }
    if (root != null) {
      await root.create(recursive: true);
    }
    final queue = _queueOverride ??
        SurveillanceUploadQueue(
          queueFile: File(p.join(root!.path, surveillanceQueueFileName)),
        );
    _queue = queue;
    await queue.load();
    await queue.scanLeftovers(now: _clock().toUtc());
    _timer = Timer.periodic(tickInterval, (_) {
      unawaited(_tick());
    });
    unawaited(_tick());
  }

  Future<Directory?> _resolveRoot(String deviceId) async {
    if (_rootOverride != null) {
      return _rootOverride;
    }
    final path = await _recorder.getRootDir(deviceId);
    if (path == null || path.isEmpty) {
      return null;
    }
    return Directory(path);
  }

  @override
  Future<void> enqueue({required String path, int? bytes}) async {
    final queue = _queue;
    if (queue == null) {
      return;
    }
    await queue.enqueue(path: path, bytes: bytes, now: _clock().toUtc());
    unawaited(_tick());
  }

  @override
  Future<void> detach() async {
    _timer?.cancel();
    _timer = null;
    _queue = null;
    _deviceId = null;
  }

  Future<void> _tick() async {
    if (_tickInFlight) {
      return;
    }
    final queue = _queue;
    final deviceId = _deviceId;
    if (queue == null || deviceId == null) {
      return;
    }
    _tickInFlight = true;
    try {
      for (final item in queue.due(now: _clock().toUtc())) {
        try {
          await _process(queue, deviceId, item);
        } catch (error) {
          AppLogger.error('SURVEILLANCE_UPLOAD_RETRY ${item.filename}', error);
          await queue.markAttempt(item.path, now: _clock().toUtc());
        }
      }
    } finally {
      _tickInFlight = false;
    }
  }

  Future<void> _process(
    SurveillanceUploadQueue queue,
    String deviceId,
    SurveillanceQueueItem item,
  ) async {
    final file = File(item.path);
    if (!file.existsSync()) {
      await queue.remove(item.path);
      return;
    }

    if (item.isPendingDelete) {
      await _deleteLocal(queue, item);
      return;
    }

    if (item.bytes <= 0) {
      item.bytes = file.lengthSync();
    }

    final granted = await _api.post(
      '/devices/$deviceId/surveillance/segments/upload-url',
      body: {
        'filename': item.filename,
        'bytes': item.bytes,
        'contentType': 'video/mp4',
        'recordedOn': item.recordedOn,
      },
    );
    final segmentId = granted['segmentId']?.toString();
    if (segmentId == null || segmentId.isEmpty) {
      throw ApiException(code: 'upload_url_failed', message: 'Missing segmentId');
    }

    if (granted['alreadyUploaded'] == true) {
      await queue.markUploadedPendingDelete(item.path, segmentId: segmentId);
      await _deleteLocal(queue, item);
      return;
    }

    final uploadUrl = granted['uploadUrl']?.toString();
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw ApiException(code: 'upload_url_failed', message: 'Missing uploadUrl');
    }

    await _api.putFileToUrl(url: uploadUrl, file: file);
    await _api.post('/devices/$deviceId/surveillance/segments/$segmentId/complete');
    await queue.markUploadedPendingDelete(item.path, segmentId: segmentId);
    await _deleteLocal(queue, item);
    AppLogger.info('SURVEILLANCE_UPLOAD_OK ${item.filename}');
  }

  Future<void> _deleteLocal(SurveillanceUploadQueue queue, SurveillanceQueueItem item) async {
    final file = File(item.path);
    try {
      if (file.existsSync()) {
        await file.delete();
      }
      await queue.remove(item.path);
    } catch (error) {
      AppLogger.error('SURVEILLANCE_DELETE_PENDING ${item.filename}', error);
    }
  }
}
