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
  });
}
