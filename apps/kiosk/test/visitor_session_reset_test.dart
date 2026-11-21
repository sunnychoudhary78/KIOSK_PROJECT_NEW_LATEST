import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/hardware/camera/camera_lease.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/session/application/visitor_session_reset.dart';
import 'package:skp_kiosk/services/print_spooler.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/printer_monitor.dart';
import 'package:skp_kiosk/services/printer/printer_native.dart';
import 'package:skp_kiosk/services/printer/usb_page_watch.dart';

class _FakeAds extends AdsController {
  @override
  AdsUiState build() => const AdsUiState();

  @override
  void showIdleNow() {}

  @override
  void resetIdleTimer() {}
}

class _SilentSpooler implements PrintSpooler {
  @override
  Future<void> printDocument({
    required String jobId,
    required String title,
    String? payloadUrl,
    String? filePath,
    Uint8List? pdfBytes,
    String colorMode = 'color',
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('resetVisitorSession releases a stuck palm camera lease', (tester) async {
    const config = AppConfig(
      apiBaseUrl: 'http://localhost/v1',
      environment: 'test',
    );
    final native = FakePrinterNative();
    final coordinator = PrintCoordinator(
      spooler: _SilentSpooler(),
      monitor: PrinterMonitor(native: native, config: config),
      usbPageWatch: UsbPageWatch(),
      reconcileTimeout: const Duration(milliseconds: 10),
    );
    final container = ProviderContainer(
      overrides: [
        adsControllerProvider.overrideWith(_FakeAds.new),
        printCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );
    addTearDown(container.dispose);
    container.listen(cameraLeaseProvider, (_, _) {});
    container.listen(adsControllerProvider, (_, _) {});

    final lease = container.read(cameraLeaseProvider.notifier);
    await lease.acquire(CameraHolder.palm);
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.palm);

    var completed = false;
    final done = container.read(visitorSessionResetProvider)(attract: false);
    unawaited(done.then((_) => completed = true));

    // Drive frames + fake time: endOfFrame, then any bestEffortTimed budgets.
    await tester.pump();
    for (var i = 0; i < 30 && !completed; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(completed, isTrue);
    expect(container.read(cameraLeaseProvider).holder, CameraHolder.none);
  });

  test('bestEffortTimed completes when work finishes under the limit', () {
    fakeAsync((async) {
      var ran = false;
      var done = false;
      bestEffortTimed(
        'ok',
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          ran = true;
        },
        const Duration(seconds: 1),
      ).then((_) => done = true);

      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();
      expect(ran, isTrue);
      expect(done, isTrue);
    });
  });

  test('bestEffortTimed returns on timeout without waiting forever', () {
    fakeAsync((async) {
      var done = false;
      bestEffortTimed(
        'hang',
        () => Completer<void>().future,
        const Duration(seconds: 5),
      ).then((_) => done = true);

      async.elapse(const Duration(seconds: 4));
      async.flushMicrotasks();
      expect(done, isFalse);

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(done, isTrue);
    });
  });

  test('bestEffortTimed swallows errors from the step', () {
    fakeAsync((async) {
      var done = false;
      bestEffortTimed(
        'boom',
        () async => throw StateError('boom'),
        const Duration(seconds: 1),
      ).then((_) => done = true);

      async.flushMicrotasks();
      expect(done, isTrue);
    });
  });
}
