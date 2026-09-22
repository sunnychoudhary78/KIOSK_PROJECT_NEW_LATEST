import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/hardware/camera/camera_lease.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_native.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_recorder.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_uploader.dart';

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

class SurveillanceState {
  const SurveillanceState({
    this.recording = false,
    this.pausedForPalm = false,
    this.error,
  });

  final bool recording;
  final bool pausedForPalm;
  final String? error;
}

class SurveillanceController extends Notifier<SurveillanceState> {
  bool _syncing = false;
  StreamSubscription<SurveillanceNativeEvent>? _events;
  void Function()? _preempt;

  @override
  SurveillanceState build() {
    final lease = ref.read(cameraLeaseProvider.notifier);
    _preempt = () {
      unawaited(_pauseForPalm());
    };
    lease.onPreemptRequested = _preempt;
    _events = ref.read(surveillanceRecorderProvider).events.listen(_onNativeEvent);
    final uploadSink = ref.read(surveillanceUploadSinkProvider);
    ref.onDispose(() {
      if (lease.onPreemptRequested == _preempt) {
        lease.onPreemptRequested = null;
      }
      unawaited(_events?.cancel());
      _events = null;
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
        await _stopRecorder();
        return;
      }

      if (holder == CameraHolder.palm) {
        return;
      }

      if (state.recording && holder == CameraHolder.surveillance) {
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
        state = const SurveillanceState(recording: true);
      }
    } catch (error) {
      AppLogger.error('Surveillance sync failed', error);
      if (!ref.mounted) {
        return;
      }
      _lease.release(CameraHolder.surveillance);
      state = SurveillanceState(error: error.toString());
    } finally {
      _syncing = false;
    }
  }

  Future<void> _stopRecorder() async {
    final holder = ref.read(cameraLeaseProvider).holder;
    if (!state.recording && !state.pausedForPalm && holder != CameraHolder.surveillance) {
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
        state = const SurveillanceState(pausedForPalm: true);
      }
    }
  }

  void _onNativeEvent(SurveillanceNativeEvent event) {
    AppLogger.info(event.type);
    if (event.type == 'SEGMENT_COMPLETED') {
      final path = event.data['path']?.toString();
      if (path != null && path.isNotEmpty) {
        final bytes = (event.data['bytes'] as num?)?.toInt();
        unawaited(
          ref.read(surveillanceUploadSinkProvider).enqueue(path: path, bytes: bytes),
        );
      }
      return;
    }
    if (event.type == 'CAMERA_ERROR' || event.type == 'STORAGE_LOW') {
      _lease.release(CameraHolder.surveillance);
      if (ref.mounted) {
        state = SurveillanceState(error: event.type);
      }
    }
  }
}

final surveillanceControllerProvider =
    NotifierProvider<SurveillanceController, SurveillanceState>(
  SurveillanceController.new,
);
