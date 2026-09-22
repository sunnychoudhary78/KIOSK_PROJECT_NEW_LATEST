import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/hardware/camera/camera_lease.dart';
import 'package:skp_kiosk/features/surveillance/application/surveillance_controller.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_recorder.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_uploader.dart';

class FakeRecorder implements SurveillanceRecorder {
  int starts = 0;
  int stops = 0;
  int pauses = 0;
  int resumes = 0;
  final _events = StreamController<SurveillanceNativeEvent>.broadcast();

  @override
  Stream<SurveillanceNativeEvent> get events => _events.stream;

  @override
  Future<void> start(SurveillanceStartConfig config) async {
    starts += 1;
  }

  @override
  Future<void> stop() async {
    stops += 1;
  }

  @override
  Future<void> pauseForPalm() async {
    pauses += 1;
  }

  @override
  Future<void> resume() async {
    resumes += 1;
  }

  @override
  Future<String?> getRootDir(String deviceId) async => null;

  void emit(SurveillanceNativeEvent event) => _events.add(event);
}

class FakeUploadSink implements SurveillanceUploadSink {
  String? attachedDeviceId;
  final enqueued = <({String path, int? bytes})>[];

  @override
  Future<void> attach({required String deviceId}) async {
    attachedDeviceId = deviceId;
  }

  @override
  Future<void> enqueue({required String path, int? bytes}) async {
    enqueued.add((path: path, bytes: bytes));
  }

  @override
  Future<void> detach() async {
    attachedDeviceId = null;
  }
}

class _DeviceAuth extends DeviceAuthNotifier {
  _DeviceAuth(this._initial);

  final DeviceAuthState _initial;

  @override
  DeviceAuthState build() => _initial;

  void emit(DeviceAuthState next) {
    state = next;
  }
}

const _authed = DeviceAuthState(
  accessToken: 'token',
  deviceId: 'device-1',
  provisioned: true,
  surveillanceEnabled: true,
);

void main() {
  late ProviderContainer container;
  late FakeRecorder recorder;
  late _DeviceAuth auth;
  late FakeUploadSink uploads;

  setUp(() {
    recorder = FakeRecorder();
    auth = _DeviceAuth(_authed);
    uploads = FakeUploadSink();
    container = ProviderContainer(
      overrides: [
        deviceAuthProvider.overrideWith(() => auth),
        surveillanceRecorderProvider.overrideWithValue(recorder),
        surveillanceUploadSinkProvider.overrideWithValue(uploads),
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://example.test/v1', environment: 'test'),
        ),
      ],
    );
    container.listen(cameraLeaseProvider, (_, _) {});
    container.listen(surveillanceControllerProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('starts native recording when authenticated and enabled', () async {
    await Future<void>.delayed(Duration.zero);
    expect(recorder.starts, 1);
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.surveillance);
    expect(container.read(surveillanceControllerProvider).recording, isTrue);
  });

  test('does not start when surveillance is off', () async {
    recorder = FakeRecorder();
    auth = _DeviceAuth(
      const DeviceAuthState(
        accessToken: 'token',
        deviceId: 'device-1',
        provisioned: true,
      ),
    );
    final offContainer = ProviderContainer(
      overrides: [
        deviceAuthProvider.overrideWith(() => auth),
        surveillanceRecorderProvider.overrideWithValue(recorder),
        surveillanceUploadSinkProvider.overrideWithValue(FakeUploadSink()),
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://example.test/v1', environment: 'test'),
        ),
      ],
    );
    addTearDown(offContainer.dispose);
    offContainer.listen(cameraLeaseProvider, (_, _) {});
    offContainer.listen(surveillanceControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(recorder.starts, 0);
  });

  test('stops when the admin flag turns off', () async {
    await Future<void>.delayed(Duration.zero);
    expect(recorder.starts, 1);
    auth.emit(
      const DeviceAuthState(
        accessToken: 'token',
        deviceId: 'device-1',
        provisioned: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(recorder.stops, 1);
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.none);
  });

  test('palm acquire preempts surveillance then resumes after release', () async {
    await Future<void>.delayed(Duration.zero);
    expect(recorder.starts, 1);

    final palm = container.read(cameraLeaseProvider.notifier).acquire(CameraHolder.palm);
    await palm;
    expect(recorder.pauses, 1);
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.palm);

    container.read(cameraLeaseProvider.notifier).release(CameraHolder.palm);
    await Future<void>.delayed(Duration.zero);
    expect(recorder.resumes, 1);
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.surveillance);
  });

  test('enqueues completed segments on the upload sink', () async {
    await Future<void>.delayed(Duration.zero);
    expect(uploads.attachedDeviceId, 'device-1');
    recorder.emit(
      const SurveillanceNativeEvent('SEGMENT_COMPLETED', {
        'path': r'C:\ProgramData\SmartKiosk\surveillance\device-1\2026-09-03\143052_abc.mp4',
        'bytes': 42,
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(uploads.enqueued, hasLength(1));
    expect(uploads.enqueued.single.path, contains('143052_abc.mp4'));
    expect(uploads.enqueued.single.bytes, 42);
  });
}
