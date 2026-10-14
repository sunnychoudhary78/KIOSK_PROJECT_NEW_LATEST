import 'package:skp_kiosk/features/surveillance/data/surveillance_upload_queue.dart';

/// Canonical health states reported to admin via heartbeat.
enum SurveillanceHealthState {
  off,
  recording,
  pausedPalm,
  uploading,
  cameraError,
  storageLow,
  stale,
  offline,
}

extension SurveillanceHealthStateApi on SurveillanceHealthState {
  String get apiValue => switch (this) {
        SurveillanceHealthState.off => 'off',
        SurveillanceHealthState.recording => 'recording',
        SurveillanceHealthState.pausedPalm => 'paused_palm',
        SurveillanceHealthState.uploading => 'uploading',
        SurveillanceHealthState.cameraError => 'camera_error',
        SurveillanceHealthState.storageLow => 'storage_low',
        SurveillanceHealthState.stale => 'stale',
        SurveillanceHealthState.offline => 'offline',
      };
}

class SurveillanceState {
  const SurveillanceState({
    this.recording = false,
    this.pausedForPalm = false,
    this.error,
    this.lastErrorAt,
    this.lastSegmentAt,
    this.lastSegmentBytes,
    this.cameraName,
    this.retryAttempt = 0,
  });

  final bool recording;
  final bool pausedForPalm;
  final String? error;
  final DateTime? lastErrorAt;
  final DateTime? lastSegmentAt;
  final int? lastSegmentBytes;
  final String? cameraName;
  final int retryAttempt;

  SurveillanceHealthState healthFor({
    required bool enabled,
    required SurveillanceQueueStats queue,
  }) {
    return resolveSurveillanceHealth(enabled: enabled, state: this, queue: queue);
  }
}

SurveillanceHealthState resolveSurveillanceHealth({
  required bool enabled,
  required SurveillanceState state,
  required SurveillanceQueueStats queue,
}) {
  if (!enabled) {
    return SurveillanceHealthState.off;
  }
  if (state.error == 'CAMERA_ERROR') {
    return SurveillanceHealthState.cameraError;
  }
  if (state.error == 'STORAGE_LOW') {
    return SurveillanceHealthState.storageLow;
  }
  if (state.error != null && state.error!.isNotEmpty) {
    return SurveillanceHealthState.cameraError;
  }
  if (state.pausedForPalm) {
    return SurveillanceHealthState.pausedPalm;
  }
  if (state.recording && queue.pendingCount > 0) {
    return SurveillanceHealthState.uploading;
  }
  if (state.recording) {
    return SurveillanceHealthState.recording;
  }
  if (queue.pendingCount > 0 || queue.failedCount > 0) {
    return SurveillanceHealthState.uploading;
  }
  return SurveillanceHealthState.stale;
}

Map<String, dynamic> surveillanceHealthPayload({
  required bool enabled,
  required SurveillanceState state,
  required SurveillanceQueueStats queue,
}) {
  final health = resolveSurveillanceHealth(enabled: enabled, state: state, queue: queue);
  return {
    'state': health.apiValue,
    'recording': state.recording,
    'lastSegmentAt': state.lastSegmentAt?.toUtc().toIso8601String(),
    'lastSegmentBytes': state.lastSegmentBytes,
    'queuePending': queue.pendingCount,
    'queueFailed': queue.failedCount,
    'oldestQueuedAt': queue.oldestQueuedAt?.toUtc().toIso8601String(),
    'lastErrorCode': state.error ?? queue.lastError,
    'lastErrorAt': state.lastErrorAt?.toUtc().toIso8601String(),
    'cameraName': state.cameraName,
  };
}
