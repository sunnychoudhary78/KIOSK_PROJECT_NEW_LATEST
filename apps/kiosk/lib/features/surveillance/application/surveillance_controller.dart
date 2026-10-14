import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/hardware/camera/camera_lease.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/features/surveillance/application/surveillance_health.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_native.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_recorder.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_uploader.dart';

export 'package:skp_kiosk/features/surveillance/application/surveillance_health.dart'
    show SurveillanceState, SurveillanceHealthState;

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

final surveillanceRecorderProvider = Provider<SurveillanceRecorder>((ref) {
  return MethodChannelSurveillanceRecorder();
});

final surveillanceUploadSinkProvider = Provider<SurveillanceUploadSink>((ref) {
  return SurveillanceUploader(
    api: ref.watch(apiClientProvider),
    recorder: ref.watch(surveillanceRecorderProvider),
  );
});

class SurveillanceController extends Notifier<SurveillanceState> {
  bool _syncing = false;
  StreamSubscription<SurveillanceNativeEvent>? _events;
  void Function()? _preempt;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  /// Injectable delays for tests.
  Duration Function(int attempt, String? error)? retryDelayFor;

  @override
  SurveillanceState build() {
    final lease = ref.read(cameraLeaseProvider.notifier);
    _preempt = () {
      unawaited(_pauseForPalm());
    };
    lease.onPreemptRequested = _preempt;
    _events = ref.read(surveillanceRecorderProvider).events.listen(_onNativeEvent);
    final uploadSink = ref.read(surveillanceUploadSinkProvider);
    surveillanceHeartbeatBodyBuilder = heartbeatPayload;
    ref.onDispose(() {
      if (identical(surveillanceHeartbeatBodyBuilder, heartbeatPayload)) {
        surveillanceHeartbeatBodyBuilder = null;
      }
      if (lease.onPreemptRequested == _preempt) {
        lease.onPreemptRequested = null;
      }
      unawaited(_events?.cancel());
      _events = null;
      _retryTimer?.cancel();
      _retryTimer = null;
      unawaited(uploadSink.detach());
    });
    ref.listen(deviceAuthProvider, (_, _) {
      unawaited(_syncUploader());
      unawaited(_sync());
    });
    ref.listen(cameraLeaseProvider, (previous, next) {
      if (previous?.holder == CameraHolder.palm && next.holder == CameraHolder.none) {
        unawaited(_sync());
      }
    });
    Future.microtask(() async {
      await _syncUploader();
      await _sync();
    });
    return const SurveillanceState();
  }

  Future<void> _syncUploader() async {
    if (!ref.mounted) {
      return;
    }
    final auth = ref.read(deviceAuthProvider);
    final sink = ref.read(surveillanceUploadSinkProvider);
    final deviceId = auth.deviceId;
    if (!auth.isAuthenticated || deviceId == null || deviceId.isEmpty) {
      await sink.detach();
      return;
    }
    await sink.attach(deviceId: deviceId);
  }

  SurveillanceRecorder get _recorder => ref.read(surveillanceRecorderProvider);
  CameraLease get _lease => ref.read(cameraLeaseProvider.notifier);

  Duration _delayForRetry(int attempt, String? error) {
    if (retryDelayFor != null) {
      return retryDelayFor!(attempt, error);
    }
    if (error == 'STORAGE_LOW') {
      return const Duration(minutes: 5);
    }
    // 15s → 30s → 60s → 5m cap
    final seconds = switch (attempt) {
      0 || 1 => 15,
      2 => 30,
      3 => 60,
      _ => 300,
    };
    return Duration(seconds: seconds);
  }

  void _scheduleRetry(String error) {
    _retryTimer?.cancel();
    _retryAttempt += 1;
    final delay = _delayForRetry(_retryAttempt, error);
    AppLogger.info('SURVEILLANCE_RETRY_SCHEDULED attempt=$_retryAttempt in=${delay.inSeconds}s');
    _retryTimer = Timer(delay, () {
      if (!ref.mounted) {
        return;
      }
      unawaited(_sync());
    });
  }

  void _clearRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
  }

  Future<void> _sync() async {
    if (_syncing || !ref.mounted) {
      return;
    }
    _syncing = true;
    try {
      final auth = ref.read(deviceAuthProvider);
      final desired = auth.isAuthenticated && auth.surveillanceEnabled;
      final holder = ref.read(cameraLeaseProvider).holder;

      if (!desired) {
        _clearRetry();
        await _stopRecorder();
        return;
      }

      if (holder == CameraHolder.palm) {
        return;
      }

      if (state.recording && holder == CameraHolder.surveillance && state.error == null) {
        return;
      }

      final deviceId = auth.deviceId;
      if (deviceId == null || deviceId.isEmpty) {
        return;
      }

      await _lease.acquire(CameraHolder.surveillance);
      if (!ref.mounted) {
        return;
      }
      final config = ref.read(appConfigProvider);
      final start = SurveillanceStartConfig(
        deviceId: deviceId,
        segmentSeconds: config.surveillanceSegmentSeconds,
        width: config.surveillanceWidth,
        height: config.surveillanceHeight,
        fps: config.surveillanceFps,
        bitrate: config.surveillanceBitrate,
        maxCacheBytes: config.surveillanceMaxCacheBytes,
      );
      if (state.pausedForPalm) {
        await _recorder.resume();
        AppLogger.info('SURVEILLANCE_RESUMED');
      } else {
        await _recorder.start(start);
        AppLogger.info('SURVEILLANCE_STARTED');
      }
      if (ref.mounted) {
        _clearRetry();
        state = SurveillanceState(
          recording: true,
          lastSegmentAt: state.lastSegmentAt,
          lastSegmentBytes: state.lastSegmentBytes,
          cameraName: state.cameraName,
        );
      }
    } catch (error) {
      AppLogger.error('Surveillance sync failed', error);
      if (!ref.mounted) {
        return;
      }
      _lease.release(CameraHolder.surveillance);
      final code = error.toString().contains('STORAGE') ? 'STORAGE_LOW' : 'CAMERA_ERROR';
      state = SurveillanceState(
        error: code,
        lastErrorAt: DateTime.now().toUtc(),
        lastSegmentAt: state.lastSegmentAt,
        lastSegmentBytes: state.lastSegmentBytes,
        cameraName: state.cameraName,
        retryAttempt: _retryAttempt + 1,
      );
      _scheduleRetry(code);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _stopRecorder() async {
    final holder = ref.read(cameraLeaseProvider).holder;
    if (!state.recording && !state.pausedForPalm && holder != CameraHolder.surveillance) {
      if (state.error != null && ref.mounted) {
        state = const SurveillanceState();
      }
      return;
    }
    try {
      await _recorder.stop();
    } catch (error) {
      AppLogger.error('Surveillance stop failed', error);
    }
    _lease.release(CameraHolder.surveillance);
    if (ref.mounted && (state.recording || state.pausedForPalm || state.error != null)) {
      state = const SurveillanceState();
      AppLogger.info('SURVEILLANCE_STOPPED');
    }
  }

  Future<void> _pauseForPalm() async {
    AppLogger.info('SURVEILLANCE_PAUSED_FOR_PALM_CAPTURE');
    try {
      await _recorder.pauseForPalm();
    } catch (error) {
      AppLogger.error('Surveillance pause failed', error);
    } finally {
      _lease.release(CameraHolder.surveillance);
      if (ref.mounted) {
        state = SurveillanceState(
          pausedForPalm: true,
          lastSegmentAt: state.lastSegmentAt,
          lastSegmentBytes: state.lastSegmentBytes,
          cameraName: state.cameraName,
        );
      }
    }
  }

  void _onNativeEvent(SurveillanceNativeEvent event) {
    AppLogger.info(event.type);
    if (event.type == 'SEGMENT_COMPLETED') {
      final path = event.data['path']?.toString();
      if (path != null && path.isNotEmpty) {
        final bytes = (event.data['bytes'] as num?)?.toInt();
        if (ref.mounted) {
          state = SurveillanceState(
            recording: state.recording,
            pausedForPalm: state.pausedForPalm,
            lastSegmentAt: DateTime.now().toUtc(),
            lastSegmentBytes: bytes,
            cameraName: state.cameraName,
          );
        }
        unawaited(
          ref.read(surveillanceUploadSinkProvider).enqueue(path: path, bytes: bytes),
        );
      }
      return;
    }
    if (event.type == 'CAMERA_ERROR' || event.type == 'STORAGE_LOW') {
      _lease.release(CameraHolder.surveillance);
      if (ref.mounted) {
        state = SurveillanceState(
          error: event.type,
          lastErrorAt: DateTime.now().toUtc(),
          lastSegmentAt: state.lastSegmentAt,
          lastSegmentBytes: state.lastSegmentBytes,
          cameraName: state.cameraName,
          retryAttempt: _retryAttempt + 1,
        );
      }
      _scheduleRetry(event.type);
    }
  }

  Map<String, dynamic> heartbeatPayload() {
    final auth = ref.read(deviceAuthProvider);
    final queue = ref.read(surveillanceUploadSinkProvider).queueStats();
    return surveillanceHealthPayload(
      enabled: auth.isAuthenticated && auth.surveillanceEnabled,
      state: state,
      queue: queue,
    );
  }
}

final surveillanceControllerProvider =
    NotifierProvider<SurveillanceController, SurveillanceState>(
  SurveillanceController.new,
);
