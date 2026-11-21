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
  SurveillanceQueueStats queueStats();
}

/// PUT timeout for surveillance segments: assume ~100 KB/s, clamp 5–15 min.
Duration surveillancePutTimeoutForBytes(int bytes) {
  const minSeconds = 5 * 60;
  const maxSeconds = 15 * 60;
  const bytesPerSecond = 100 * 1024;
  final estimated = bytes <= 0 ? minSeconds : (bytes / bytesPerSecond).ceil();
  return Duration(seconds: estimated.clamp(minSeconds, maxSeconds));
}

/// Wall timeout slightly above PUT timeout so hung requests cannot wedge the tick.
Duration surveillanceProcessTimeoutForBytes(int bytes) {
  return surveillancePutTimeoutForBytes(bytes) + const Duration(minutes: 1);
}

/// Errors that should never leave the queue (corrupt/stub only).
bool surveillanceIsPermanentUploadError(String code) => code == 'invalid_segment';

typedef SurveillanceUnauthorizedHandler = Future<bool> Function();

class SurveillanceUploader implements SurveillanceUploadSink {
  SurveillanceUploader({
    required ApiClient api,
    required SurveillanceRecorder recorder,
    this.tickInterval = const Duration(seconds: 5),
    DateTime Function()? clock,
    Directory? rootOverride,
    SurveillanceUploadQueue? queue,
    SurveillanceUnauthorizedHandler? onUnauthorized,
  })  : _api = api,
        _recorder = recorder,
        _clock = clock ?? DateTime.now,
        _rootOverride = rootOverride,
        _queueOverride = queue,
        _onUnauthorized = onUnauthorized;

  final ApiClient _api;
  final SurveillanceRecorder _recorder;
  final Duration tickInterval;
  final DateTime Function() _clock;
  final Directory? _rootOverride;
  final SurveillanceUploadQueue? _queueOverride;
  final SurveillanceUnauthorizedHandler? _onUnauthorized;

  SurveillanceUploadQueue? _queue;
  String? _deviceId;
  Timer? _timer;
  bool _tickInFlight = false;
  String? _lastError;

  String? get deviceId => _deviceId;

  @override
  SurveillanceQueueStats queueStats() {
    final queue = _queue;
    if (queue == null) {
      return SurveillanceQueueStats(
        pendingCount: 0,
        failedCount: 0,
        dueCount: 0,
        lastError: _lastError,
      );
    }
    final stats = queue.stats(now: _clock().toUtc());
    return SurveillanceQueueStats(
      pendingCount: stats.pendingCount,
      failedCount: stats.failedCount,
      dueCount: stats.dueCount,
      oldestQueuedAt: stats.oldestQueuedAt,
      lastError: stats.lastError ?? _lastError,
    );
  }

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
    final healedLoad = await queue.load();
    final healedScan = await queue.scanLeftovers(now: _clock().toUtc());
    final healed = healedLoad + healedScan;
    final stats = queue.stats(now: _clock().toUtc());
    if (healed > 0) {
      AppLogger.info(
        'SURVEILLANCE_QUEUE_HEALED healed=$healed '
        'pending=${stats.pendingCount} due=${stats.dueCount}',
      );
    }
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
    var unauthorizedRetried = false;
    try {
      final stats = queue.stats(now: _clock().toUtc());
      final batchSize = stats.pendingCount > surveillanceBacklogPendingLimit &&
              stats.dueCount > 0
          ? 3
          : 1;

      for (var i = 0; i < batchSize; i++) {
        final due = queue.due(now: _clock().toUtc());
        if (due.isEmpty) {
          return;
        }
        final item = due.first;
        final started = _clock().toUtc();
        try {
          await _processWithTimeout(queue, deviceId, item);
        } catch (error) {
          final code = error is ApiException ? error.code : 'upload_failed';
          _lastError = code;
          final durationMs = _clock().toUtc().difference(started).inMilliseconds;

          if (code == 'unauthorized' &&
              !unauthorizedRetried &&
              _onUnauthorized != null) {
            unauthorizedRetried = true;
            final refreshed = await _onUnauthorized!();
            if (refreshed) {
              AppLogger.info(
                'SURVEILLANCE_UPLOAD_AUTH_REFRESHED ${item.filename}',
              );
              try {
                await _processWithTimeout(queue, deviceId, item);
                continue;
              } catch (retryError) {
                final retryCode =
                    retryError is ApiException ? retryError.code : 'upload_failed';
                _lastError = retryCode;
                AppLogger.error(
                  'SURVEILLANCE_UPLOAD_RETRY ${item.filename} '
                  'attempts=${item.attempts + 1} errorCode=$retryCode '
                  'bytes=${item.bytes} durationMs=$durationMs',
                  retryError,
                );
                if (surveillanceIsPermanentUploadError(retryCode)) {
                  await queue.markFailed(item.path, error: retryCode);
                } else {
                  await queue.markAttempt(
                    item.path,
                    now: _clock().toUtc(),
                    error: retryCode,
                  );
                }
                continue;
              }
            }
          }

          AppLogger.error(
            'SURVEILLANCE_UPLOAD_RETRY ${item.filename} '
            'attempts=${item.attempts + 1} errorCode=$code '
            'bytes=${item.bytes} durationMs=$durationMs',
            error,
          );
          if (surveillanceIsPermanentUploadError(code)) {
            await queue.markFailed(item.path, error: code);
          } else {
            await queue.markAttempt(item.path, now: _clock().toUtc(), error: code);
          }
        }
      }
    } finally {
      _tickInFlight = false;
    }
  }

  Future<void> _processWithTimeout(
    SurveillanceUploadQueue queue,
    String deviceId,
    SurveillanceQueueItem item,
  ) async {
    final timeout = surveillanceProcessTimeoutForBytes(item.bytes);
    try {
      await _process(queue, deviceId, item).timeout(timeout);
    } on TimeoutException {
      AppLogger.error(
        'SURVEILLANCE_UPLOAD_STUCK ${item.filename} '
        'bytes=${item.bytes} timeoutSec=${timeout.inSeconds}',
      );
      throw ApiException(
        code: 'upload_timeout',
        message: 'Upload exceeded ${timeout.inSeconds}s',
      );
    }
  }

  Future<void> _process(
    SurveillanceUploadQueue queue,
    String deviceId,
    SurveillanceQueueItem item,
  ) async {
    final started = _clock().toUtc();
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

    if (item.bytes < surveillanceMinSegmentBytes) {
      AppLogger.error(
        'SURVEILLANCE_UPLOAD_REJECT ${item.filename} bytes=${item.bytes} '
        'attempts=${item.attempts} errorCode=invalid_segment',
      );
      _lastError = 'invalid_segment';
      await queue.markFailed(item.path, error: 'invalid_segment');
      return;
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

    await _api.putFileToUrl(
      url: uploadUrl,
      file: file,
      timeout: surveillancePutTimeoutForBytes(item.bytes),
    );

    try {
      await _api.post('/devices/$deviceId/surveillance/segments/$segmentId/complete');
    } on ApiException catch (error) {
      // size_mismatch deletes the bad object server-side; re-PUT on next tick.
      // upload_incomplete means PUT may not have landed — also retry.
      if (error.code == 'size_mismatch' ||
          error.code == 'upload_incomplete' ||
          error.code == 'invalid_segment') {
        rethrow;
      }
      rethrow;
    }

    await queue.markUploadedPendingDelete(item.path, segmentId: segmentId);
    await _deleteLocal(queue, item);
    _lastError = null;
    final durationMs = _clock().toUtc().difference(started).inMilliseconds;
    AppLogger.info(
      'SURVEILLANCE_UPLOAD_OK ${item.filename} attempts=${item.attempts} '
      'bytes=${item.bytes} durationMs=$durationMs',
    );
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
