import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/services/print_spooler.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/print_reconcile_result.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';
import 'package:skp_kiosk/services/printer/printer_monitor.dart';
import 'package:skp_kiosk/services/printer/printer_native.dart';
import 'package:skp_kiosk/services/printer/usb_page_watch.dart';
import 'package:skp_kiosk/services/printer/usb_snapshot.dart';

class _FakeSpooler implements PrintSpooler {
  bool shouldFail = false;
  int calls = 0;

  @override
  Future<void> printDocument({
    required String jobId,
    required String title,
    String? payloadUrl,
    String? filePath,
    Uint8List? pdfBytes,
    String colorMode = 'color',
  }) async {
    calls++;
    if (shouldFail) {
      throw StateError('spooler rejected');
    }
  }
}

typedef _Report = Future<void> Function({
  required String jobId,
  required String status,
  String? errorMessage,
  int? pagesReported,
  String? spoolerJobId,
  int? pageCounterBefore,
  int? pageCounterAfter,
  String? reconcileStatus,
  String? reconcileDetail,
  bool? needsAdminReview,
  bool? holdForRetry,
});

_Report _collecting(_Report? inner, List<Map<String, dynamic>> reports) {
  return ({
    required String jobId,
    required String status,
    String? errorMessage,
    int? pagesReported,
    String? spoolerJobId,
    int? pageCounterBefore,
    int? pageCounterAfter,
    String? reconcileStatus,
    String? reconcileDetail,
    bool? needsAdminReview,
    bool? holdForRetry,
  }) async {
    reports.add({
      'status': status,
      'reconcileStatus': reconcileStatus,
      'pagesReported': pagesReported,
      'needsAdminReview': needsAdminReview,
    });
    if (inner != null) {
      await inner(
        jobId: jobId,
        status: status,
        errorMessage: errorMessage,
        pagesReported: pagesReported,
        spoolerJobId: spoolerJobId,
        pageCounterBefore: pageCounterBefore,
        pageCounterAfter: pageCounterAfter,
        reconcileStatus: reconcileStatus,
        reconcileDetail: reconcileDetail,
        needsAdminReview: needsAdminReview,
        holdForRetry: holdForRetry,
      );
    }
  };
}

void main() {
  final pdf = Uint8List.fromList([1, 2, 3]);

  AppConfig testConfig() => const AppConfig(
        apiBaseUrl: 'http://localhost/v1',
        environment: 'test',
        printReconcileTimeoutMs: 200,
      );

  PrintCoordinator buildCoordinator({
    required FakePrinterNative native,
    _FakeSpooler? spooler,
    UsbPageWatch? usbPageWatch,
    Duration? reconcileTimeout,
    Duration? usbBaselineGrace,
    Duration? pollInterval,
    Duration? counterRetryDelay,
    int counterRetryAttempts = 2,
  }) {
    return PrintCoordinator(
      spooler: spooler ?? _FakeSpooler(),
      monitor: PrinterMonitor(
        native: native,
        config: testConfig(),
        usbPageWatch: usbPageWatch,
      ),
      usbPageWatch: usbPageWatch,
      pollInterval: pollInterval ?? const Duration(milliseconds: 20),
      counterRetryAttempts: counterRetryAttempts,
      counterRetryDelay: counterRetryDelay ?? const Duration(milliseconds: 5),
      usbBaselineGrace: usbBaselineGrace ?? const Duration(milliseconds: 60),
      reconcileTimeout: reconcileTimeout ?? const Duration(milliseconds: 120),
    );
  }

  Future<void> quietReport({
    required String jobId,
    required String status,
    String? errorMessage,
    int? pagesReported,
    String? spoolerJobId,
    int? pageCounterBefore,
    int? pageCounterAfter,
    String? reconcileStatus,
    String? reconcileDetail,
    bool? needsAdminReview,
    bool? holdForRetry,
  }) async {}

  test('missing USB baseline ends unknown after the grace wait', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true),
    );
    final spooler = _FakeSpooler();
    final coordinator = buildCoordinator(
      native: native,
      spooler: spooler,
      usbBaselineGrace: const Duration(milliseconds: 80),
      pollInterval: const Duration(milliseconds: 20),
    );
    final progress = <String>[];
    final started = DateTime.now();

    final result = await coordinator.printAndReconcile(
      jobId: 'job-3',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: quietReport,
      onProgress: progress.add,
    );
    final elapsed = DateTime.now().difference(started);

    expect(result.outcome, PrintReconcileOutcome.unknown);
    expect(result.reconcileDetail, 'usb_baseline_unavailable');
    expect(progress, contains('Printer processing…'));
    expect(elapsed.inMilliseconds, greaterThanOrEqualTo(60));
    expect(spooler.calls, 1);
  });

  test('failed with zero pages on jam before print', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(
        state: 'jam',
        online: true,
        lastErrorCode: 'PAPER_JAM',
      ),
    );
    final spooler = _FakeSpooler();
    final coordinator = buildCoordinator(
      native: native,
      spooler: spooler,
    );

    final result = await coordinator.printAndReconcile(
      jobId: 'job-4',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: quietReport,
    );

    expect(result.outcome, PrintReconcileOutcome.failed);
    expect(spooler.calls, 0);
    expect(result.userMessage, contains('jam'));
  });

  test('idle spooler without a USB baseline does not verify', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(
        state: 'ready',
        online: true,
        hrPrinterStatus: 3,
        hrPrinterStatusLabel: 'idle',
        spoolerJobsQueued: 0,
        spoolerJobsPrinting: 0,
      ),
    );
    final coordinator = buildCoordinator(native: native);
    final reports = <Map<String, dynamic>>[];

    final result = await coordinator.printAndReconcile(
      jobId: 'job-idle-only',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: _collecting(null, reports),
    );

    expect(result.outcome, PrintReconcileOutcome.unknown);
    expect(result.reconcileDetail, 'usb_baseline_unavailable');
    expect(reports.last['reconcileStatus'], isNot('verified'));
  });

  test('paper_out before print fails without verifying', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(
        state: 'paper_out',
        online: true,
        noPaper: true,
      ),
    );
    final coordinator = buildCoordinator(native: native);

    final result = await coordinator.printAndReconcile(
      jobId: 'job-paper',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: quietReport,
    );

    expect(result.outcome, PrintReconcileOutcome.failed);
    expect(result.reconcileDetail, 'paper_out');
  });

  test('abortAndReset unlocks so next print is not busy', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true),
    );
    final coordinator = buildCoordinator(
      native: native,
      pollInterval: const Duration(milliseconds: 40),
      reconcileTimeout: const Duration(seconds: 2),
    );

    final first = coordinator.printAndReconcile(
      jobId: 'job-abort-a',
      title: 'a.pdf',
      pdfBytes: pdf,
      pagesExpected: 5,
      colorMode: 'bw',
      reportStatus: quietReport,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(coordinator.isLocked, isTrue);
    coordinator.abortAndReset();
    expect(coordinator.isLocked, isFalse);

    final second = await coordinator.printAndReconcile(
      jobId: 'job-abort-b',
      title: 'b.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: quietReport,
    );
    expect(second.outcome, isNot(PrintReconcileOutcome.busy));
    final firstResult = await first;
    expect(firstResult.reconcileDetail, 'aborted');
  });

  test('busy when a second job starts while locked', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true),
    );
    final coordinator = buildCoordinator(
      native: native,
      pollInterval: const Duration(milliseconds: 40),
      reconcileTimeout: const Duration(milliseconds: 300),
    );

    final first = coordinator.printAndReconcile(
      jobId: 'job-a',
      title: 'a.pdf',
      pdfBytes: pdf,
      pagesExpected: 5,
      colorMode: 'bw',
      reportStatus: quietReport,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final second = await coordinator.printAndReconcile(
      jobId: 'job-b',
      title: 'b.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: quietReport,
    );
    expect(second.outcome, PrintReconcileOutcome.busy);
    await first;
  });

  test('verified from USB page total', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true),
    );
    final watch = UsbPageWatch();
    watch.record(const UsbSnapshot(ok: true, connected: true, pagesTotal: 186));
    final coordinator = buildCoordinator(
      native: native,
      usbPageWatch: watch,
      reconcileTimeout: const Duration(seconds: 2),
    );
    Future<void>.delayed(const Duration(milliseconds: 30), () {
      watch.record(const UsbSnapshot(ok: true, connected: true, pagesTotal: 190));
    });

    final result = await coordinator.printAndReconcile(
      jobId: 'job-usb-color',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 4,
      colorMode: 'color',
      reportStatus: quietReport,
    );

    expect(result.outcome, PrintReconcileOutcome.verified);
    expect(result.reconcileDetail, 'usb_page_delta');
    expect(result.pageCounterBefore, 186);
    expect(result.pageCounterAfter, 190);
    expect(result.pagesReported, 4);
    expect(native.usbSnapshotCalls, 0);
  });

  test('failed USB baseline ends unknown', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true),
    );
    final coordinator = buildCoordinator(
      native: native,
      usbBaselineGrace: const Duration(milliseconds: 40),
    );

    final result = await coordinator.printAndReconcile(
      jobId: 'job-usb-fallback',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 4,
      colorMode: 'bw',
      reportStatus: quietReport,
    );

    expect(result.outcome, PrintReconcileOutcome.unknown);
    expect(result.reconcileDetail, 'usb_baseline_unavailable');
    expect(native.usbSnapshotCalls, 2);
  });

  test('flat USB total does not verify', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true),
    );
    final watch = UsbPageWatch();
    watch.record(const UsbSnapshot(ok: true, connected: true, pagesTotal: 186));
    final coordinator = buildCoordinator(
      native: native,
      usbPageWatch: watch,
      reconcileTimeout: const Duration(milliseconds: 80),
    );

    final result = await coordinator.printAndReconcile(
      jobId: 'job-usb-flat',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 4,
      colorMode: 'bw',
      reportStatus: quietReport,
    );

    expect(result.outcome, PrintReconcileOutcome.reconciliationRequired);
    expect(result.reconcileDetail, 'timeout');
    expect(result.pageCounterBefore, 186);
    expect(result.pageCounterAfter, 186);
    expect(native.usbSnapshotCalls, 0);
  });

  test('a failed USB sample then a later rise still verifies', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true),
    );
    final watch = UsbPageWatch();
    watch.record(const UsbSnapshot(ok: true, connected: true, pagesTotal: 186));
    final coordinator = buildCoordinator(
      native: native,
      usbPageWatch: watch,
      reconcileTimeout: const Duration(seconds: 2),
    );
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      watch.record(UsbSnapshot.failed('busy'));
      watch.record(const UsbSnapshot(ok: true, connected: true, pagesTotal: 190));
    });

    final result = await coordinator.printAndReconcile(
      jobId: 'job-usb-busy',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 4,
      colorMode: 'color',
      reportStatus: quietReport,
    );

    expect(result.outcome, PrintReconcileOutcome.verified);
    expect(result.reconcileDetail, 'usb_page_delta');
    expect(result.pagesReported, 4);
    expect(result.pageCounterBefore, 186);
    expect(result.pageCounterAfter, 190);
    expect(native.usbSnapshotCalls, 0);
  });

  test('latched USB paper-out fails the job even if the page total would verify',
      () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true),
    );
    final watch = UsbPageWatch();
    watch.record(
      const UsbSnapshot(
        ok: true,
        connected: true,
        pagesTotal: 186,
        statusCode: usbStatusPaperOut,
        statusMessage: 'No Paper T1',
      ),
    );
    final spooler = _FakeSpooler();
    final coordinator = buildCoordinator(
      native: native,
      spooler: spooler,
      usbPageWatch: watch,
      reconcileTimeout: const Duration(seconds: 2),
    );
    Future<void>.delayed(const Duration(milliseconds: 30), () {
      watch.record(
        const UsbSnapshot(
          ok: true,
          connected: true,
          pagesTotal: 190,
          statusCode: usbStatusPaperOut,
          statusMessage: 'No Paper T1',
        ),
      );
    });

    final result = await coordinator.printAndReconcile(
      jobId: 'job-usb-paper-latch',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 4,
      colorMode: 'bw',
      reportStatus: quietReport,
    );

    expect(result.outcome, PrintReconcileOutcome.failed);
    expect(result.reconcileDetail, 'paper_out');
    expect(result.pagesReported, 0);
    expect(spooler.calls, 0);
  });
}
