import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/hardware/camera/camera_lease.dart';

void main() {
  late ProviderContainer container;
  late CameraLease lease;

  setUp(() {
    container = ProviderContainer();
    container.listen(cameraLeaseProvider, (_, _) {});
    lease = container.read(cameraLeaseProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('palm acquire when free', () async {
    await lease.acquire(CameraHolder.palm);
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.palm);
  });

  test('idempotent re-acquire by palm', () async {
    await lease.acquire(CameraHolder.palm);
    await lease.acquire(CameraHolder.palm);
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.palm);
  });

  test('palm waits for surveillance release and preempts once', () async {
    var preempts = 0;
    lease.onPreemptRequested = () => preempts += 1;

    await lease.acquire(CameraHolder.surveillance);
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.surveillance);

    final palm = lease.acquire(CameraHolder.palm);
    await Future<void>.delayed(Duration.zero);
    expect(preempts, 1);
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.surveillance);

    lease.release(CameraHolder.surveillance);
    await palm;
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.palm);
    expect(preempts, 1);
  });

  test('release of the wrong holder is a no-op', () async {
    await lease.acquire(CameraHolder.palm);
    lease.release(CameraHolder.surveillance);
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.palm);
  });

  test('acquire times out when the other holder never releases', () async {
    await lease.acquire(CameraHolder.surveillance);
    await expectLater(
      lease.acquire(CameraHolder.palm, timeout: const Duration(milliseconds: 20)),
      throwsA(isA<CameraLeaseTimeout>()),
    );
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.surveillance);
  });
}
