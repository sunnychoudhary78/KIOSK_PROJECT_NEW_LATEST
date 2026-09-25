import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_hold.dart';
import 'package:skp_kiosk/features/session/application/visitor_session_reset.dart';
import 'package:skp_kiosk/features/session/domain/kiosk_session_policy.dart';

class _AuthedDeviceAuth extends DeviceAuthNotifier {
  @override
  DeviceAuthState build() {
    return const DeviceAuthState(accessToken: 'token', deviceId: 'device-1');
  }
}

void main() {
  const policy = KioskSessionPolicy(
    idleTimeout: Duration(seconds: 5),
    warningDuration: Duration(seconds: 3),
    consentIdleTimeout: Duration(minutes: 4),
  );

  ProviderContainer containerOf(List<bool> resets) {
    return ProviderContainer(
      overrides: [
        kioskSessionPolicyProvider.overrideWithValue(policy),
        visitorSessionResetProvider.overrideWithValue(({required bool attract}) async {
          resets.add(attract);
        }),
        deviceAuthProvider.overrideWith(_AuthedDeviceAuth.new),
      ],
    );
  }

  test('inService goes to warning then reset with attract', () {
    fakeAsync((async) {
      final resets = <bool>[];
      final container = containerOf(resets);
      addTearDown(container.dispose);
      container.listen(kioskSessionControllerProvider, (_, _) {});
      final session = container.read(kioskSessionControllerProvider.notifier);

      session.setOnHome(false);
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.inService);

      async.elapse(const Duration(seconds: 5));
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.warning);
      expect(resets, isEmpty);

      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      expect(resets, [true]);
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.catalog);
    });
  });

  test('activity during warning returns to inService', () {
    fakeAsync((async) {
      final resets = <bool>[];
      final container = containerOf(resets);
      addTearDown(container.dispose);
      container.listen(kioskSessionControllerProvider, (_, _) {});
      final session = container.read(kioskSessionControllerProvider.notifier);

      session.setOnHome(false);
      async.elapse(const Duration(seconds: 5));
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.warning);

      session.noteActivity();
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.inService);
      expect(resets, isEmpty);

      async.elapse(const Duration(seconds: 4));
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.inService);

      async.elapse(const Duration(seconds: 1));
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.warning);
    });
  });

  test('printing holds the idle timer', () {
    fakeAsync((async) {
      final resets = <bool>[];
      final container = containerOf(resets);
      addTearDown(container.dispose);
      container.listen(kioskSessionControllerProvider, (_, _) {});
      final session = container.read(kioskSessionControllerProvider.notifier);

      session.setOnHome(false);
      container.read(kioskSessionHoldProvider.notifier).set(printing: true);
      async.elapse(const Duration(minutes: 2));
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.inService);
      expect(resets, isEmpty);

      container.read(kioskSessionHoldProvider.notifier).set(printing: false);
      async.elapse(const Duration(seconds: 5));
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.warning);
    });
  });

  test('waiting holds the idle timer', () {
    fakeAsync((async) {
      final resets = <bool>[];
      final container = containerOf(resets);
      addTearDown(container.dispose);
      container.listen(kioskSessionControllerProvider, (_, _) {});
      final session = container.read(kioskSessionControllerProvider.notifier);

      session.setOnHome(false);
      container.read(kioskSessionHoldProvider.notifier).set(waiting: true);
      async.elapse(const Duration(minutes: 2));
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.inService);
      expect(resets, isEmpty);

      container.read(kioskSessionHoldProvider.notifier).set(waiting: false);
      async.elapse(const Duration(seconds: 5));
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.warning);
    });
  });

  test('catalog does not warn', () {
    fakeAsync((async) {
      final resets = <bool>[];
      final container = containerOf(resets);
      addTearDown(container.dispose);
      container.listen(kioskSessionControllerProvider, (_, _) {});

      async.elapse(const Duration(minutes: 5));
      expect(container.read(kioskSessionControllerProvider).phase, KioskSessionPhase.catalog);
      expect(resets, isEmpty);
    });
  });
}
