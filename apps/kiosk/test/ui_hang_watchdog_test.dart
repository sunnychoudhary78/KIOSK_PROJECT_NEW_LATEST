import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/runtime/ui_hang_watchdog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolveEnabled respects dart-define override via constructor', () {
    expect(
      UiHangWatchdog(enabledOverride: true).isEnabled,
      isTrue,
    );
    expect(
      UiHangWatchdog(enabledOverride: false).isEnabled,
      isFalse,
    );
  });

  test('invokes onHang when no frames arrive within the limit', () {
    fakeAsync((async) {
      var hung = false;
      var now = DateTime.utc(2026, 1, 1, 12);
      final watchdog = UiHangWatchdog(
        enabledOverride: true,
        noFrameLimit: const Duration(seconds: 45),
        pollInterval: const Duration(seconds: 5),
        clock: () => now,
        onHang: () => hung = true,
      );

      watchdog.start();
      async.flushMicrotasks();
      expect(hung, isFalse);

      now = now.add(const Duration(seconds: 40));
      async.elapse(const Duration(seconds: 40));
      expect(hung, isFalse);

      now = now.add(const Duration(seconds: 10));
      async.elapse(const Duration(seconds: 10));
      expect(hung, isTrue);

      watchdog.stop();
    });
  });

  test('disabled watchdog never fires onHang', () {
    fakeAsync((async) {
      var hung = false;
      var now = DateTime.utc(2026, 1, 1, 12);
      final watchdog = UiHangWatchdog(
        enabledOverride: false,
        noFrameLimit: const Duration(seconds: 1),
        pollInterval: const Duration(milliseconds: 500),
        clock: () => now,
        onHang: () => hung = true,
      );

      watchdog.start();
      now = now.add(const Duration(seconds: 30));
      async.elapse(const Duration(seconds: 30));
      expect(hung, isFalse);
      watchdog.stop();
    });
  });
}
