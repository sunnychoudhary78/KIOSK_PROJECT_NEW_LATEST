import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/surveillance/application/surveillance_health.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_upload_queue.dart';

void main() {
  test('maps camera error and upload backlog to health states', () {
    expect(
      resolveSurveillanceHealth(
        enabled: false,
        state: const SurveillanceState(),
        queue: const SurveillanceQueueStats(pendingCount: 0, failedCount: 0),
      ),
      SurveillanceHealthState.off,
    );

    expect(
      resolveSurveillanceHealth(
        enabled: true,
        state: const SurveillanceState(recording: true),
        queue: const SurveillanceQueueStats(pendingCount: 0, failedCount: 0),
      ),
      SurveillanceHealthState.recording,
    );

    expect(
      resolveSurveillanceHealth(
        enabled: true,
        state: const SurveillanceState(recording: true),
        queue: const SurveillanceQueueStats(pendingCount: 3, failedCount: 0),
      ),
      SurveillanceHealthState.uploading,
    );

    expect(
      resolveSurveillanceHealth(
        enabled: true,
        state: const SurveillanceState(error: 'CAMERA_ERROR'),
        queue: const SurveillanceQueueStats(pendingCount: 0, failedCount: 0),
      ),
      SurveillanceHealthState.cameraError,
    );

    expect(
      resolveSurveillanceHealth(
        enabled: true,
        state: const SurveillanceState(error: 'UPLOAD_BACKLOG'),
        queue: const SurveillanceQueueStats(pendingCount: 21, failedCount: 0),
      ),
      SurveillanceHealthState.uploading,
    );
  });

  test('heartbeat payload includes lastErrorDetail', () {
    final payload = surveillanceHealthPayload(
      enabled: true,
      state: const SurveillanceState(
        error: 'CAMERA_ERROR',
        errorDetail: 'step=InitEngine hr=0xC00D36B4',
      ),
      queue: const SurveillanceQueueStats(pendingCount: 0, failedCount: 0),
    );
    expect(payload['lastErrorCode'], 'CAMERA_ERROR');
    expect(payload['lastErrorDetail'], 'step=InitEngine hr=0xC00D36B4');
    expect(payload['state'], 'camera_error');
  });
}
