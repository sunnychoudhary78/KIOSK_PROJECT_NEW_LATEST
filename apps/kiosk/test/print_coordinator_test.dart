import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/services/print_spooler.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/print_reconcile_result.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';
import 'package:skp_kiosk/services/printer/printer_monitor.dart';
import 'package:skp_kiosk/services/printer/printer_native.dart';

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

  AppConfig snmpConfig() => const AppConfig(
        apiBaseUrl: 'http://localhost/v1',
        environment: 'test',
        printerSnmpHost: '192.168.1.13',
        printerSnmpCommunity: 'public',
        printReconcileTimeoutMs: 200,
      );

  AppConfig noSnmpConfig() => const AppConfig(
        apiBaseUrl: 'http://localhost/v1',
        environment: 'test',
        printReconcileTimeoutMs: 200,
      );

  PrintCoordinator buildCoordinator({
    required FakePrinterNative native,
    required AppConfig config,
    _FakeSpooler? spooler,
    Duration? reconcileTimeout,
    Duration? noSnmpGrace,
    Duration? pollInterval,
    Duration? counterRetryDelay,
    int counterRetryAttempts = 2,
  }) {
    return PrintCoordinator(
      spooler: spooler ?? _FakeSpooler(),
      monitor: PrinterMonitor(native: native, config: config),
      pollInterval: pollInterval ?? const Duration(milliseconds: 20),
      counterRetryAttempts: counterRetryAttempts,
      counterRetryDelay: counterRetryDelay ?? const Duration(milliseconds: 5),
      noSnmpGrace: noSnmpGrace ?? const Duration(milliseconds: 60),
      reconcileTimeout: reconcileTimeout ?? const Duration(milliseconds: 120),
    );
  }

  test('verified when SNMP page counter advances', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true, snmpOk: true),
      pageCounterSequence: [100, 100, 101],
    );
    final spooler = _FakeSpooler();
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      spooler: spooler,
      reconcileTimeout: const Duration(seconds: 2),
    );
    final reports = <Map<String, dynamic>>[];

    final result = await coordinator.printAndReconcile(
      jobId: 'job-1',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: _collecting(null, reports),
    );

    expect(result.outcome, PrintReconcileOutcome.verified);
    expect(spooler.calls, 1);
    expect(reports.last['status'], 'completed');
    expect(reports.last['reconcileStatus'], 'verified');
  });

  test('verified after initial SNMP misses then page delta', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true, snmpOk: true),
      // getHealth does not consume sequence; only getPageCounter does.
      pageCounterSequence: [
        null, null, // counter retries (attempts=2)
        null, // poll 1 — still miss
        100, // poll 2 — provisional watermark
        101, // poll 3 — rise → verified
      ],
    );
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      counterRetryAttempts: 2,
      reconcileTimeout: const Duration(seconds: 2),
    );
    final progress = <String>[];

    final result = await coordinator.printAndReconcile(
      jobId: 'job-delayed',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: ({
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
      }) async {},
      onProgress: progress.add,
    );

    expect(result.outcome, PrintReconcileOutcome.verified);
    expect(progress, contains('Printer processing…'));
    expect(progress, contains('Confirming print…'));
    expect(progress, isNot(contains('Could not confirm print on the printer…')));
  });

  test('reconciliation_required on timeout without page delta', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true, snmpOk: true),
      pageCounter: 50,
    );
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      reconcileTimeout: const Duration(milliseconds: 80),
    );
    final reports = <Map<String, dynamic>>[];

    final result = await coordinator.printAndReconcile(
      jobId: 'job-2',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 2,
      colorMode: 'bw',
      reportStatus: _collecting(null, reports),
    );

    expect(result.outcome, PrintReconcileOutcome.reconciliationRequired);
    expect(reports.last['status'], 'printing');
    expect(reports.last['reconcileStatus'], 'reconciliation_required');
    expect(reports.last['needsAdminReview'], true);
  });

  test('unknown after timeout when SNMP counter never readable', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true),
      pageCounter: null,
    );
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      counterRetryAttempts: 2,
      reconcileTimeout: const Duration(milliseconds: 80),
    );
    final started = DateTime.now();
    final result = await coordinator.printAndReconcile(
      jobId: 'job-null-counter',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: ({
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
      }) async {},
    );
    final elapsed = DateTime.now().difference(started);

    expect(result.outcome, PrintReconcileOutcome.unknown);
    expect(elapsed.inMilliseconds, greaterThanOrEqualTo(60));
  });

  test('unknown when SNMP is not configured only after grace', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true),
    );
    final coordinator = buildCoordinator(
      native: native,
      config: noSnmpConfig(),
      noSnmpGrace: const Duration(milliseconds: 80),
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
      reportStatus: ({
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
      }) async {},
      onProgress: progress.add,
    );
    final elapsed = DateTime.now().difference(started);

    expect(result.outcome, PrintReconcileOutcome.unknown);
    expect(progress, contains('Printer processing…'));
    expect(elapsed.inMilliseconds, greaterThanOrEqualTo(60));
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
      config: snmpConfig(),
      spooler: spooler,
    );

    final result = await coordinator.printAndReconcile(
      jobId: 'job-4',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: ({
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
      }) async {},
    );

    expect(result.outcome, PrintReconcileOutcome.failed);
    expect(spooler.calls, 0);
    expect(result.userMessage, contains('jam'));
  });

  test('does not verify from idle/spooler alone without page delta', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(
        state: 'ready',
        online: true,
        snmpOk: true,
        hrPrinterStatus: 3,
        hrPrinterStatusLabel: 'idle',
        spoolerJobsQueued: 0,
        spoolerJobsPrinting: 0,
      ),
      pageCounter: 50,
    );
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      reconcileTimeout: const Duration(milliseconds: 80),
    );
    final reports = <Map<String, dynamic>>[];

    final result = await coordinator.printAndReconcile(
      jobId: 'job-idle-only',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: _collecting(null, reports),
    );

    expect(result.outcome, PrintReconcileOutcome.reconciliationRequired);
    expect(reports.last['reconcileStatus'], isNot('verified'));
  });

  test('paper_out mid-job fails without verifying', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(
        state: 'paper_out',
        online: true,
        noPaper: true,
        errorFlagsHex: '40',
        snmpOk: true,
        snmpReachable: true,
        snmpConfigured: true,
      ),
      pageCounter: 10,
    );
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      reconcileTimeout: const Duration(milliseconds: 200),
    );

    final result = await coordinator.printAndReconcile(
      jobId: 'job-paper',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: ({
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
      }) async {},
    );

    // Fatal on preHealth before spooler send.
    expect(result.outcome, PrintReconcileOutcome.failed);
    expect(result.reconcileDetail, 'paper_out');
  });

  test('SNMP unreachable mid-reconcile does not fail; page delta still verifies',
      () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(
        state: 'ready',
        online: true,
        snmpOk: true,
        snmpConfigured: true,
        snmpReachable: true,
      ),
      // After preHealth, simulate lab timeouts (reachable false) mid-wait.
      healthAfterFirst: const PrinterHealth(
        state: 'ready',
        online: true,
        snmpOk: false,
        snmpConfigured: true,
        snmpReachable: false,
        consecutiveFailures: 5,
        offlineBit: true,
      ),
      pageCounterSequence: [20, 20, 21],
    );
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      reconcileTimeout: const Duration(seconds: 2),
    );

    final result = await coordinator.printAndReconcile(
      jobId: 'job-blip',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: ({
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
      }) async {},
    );

    expect(result.outcome, PrintReconcileOutcome.verified);
  });

  test('pageCounterFromNative ignores a stale forced refresh', () {
    expect(
      pageCounterFromNative(
        {'ok': true, 'stale': true, 'pageCounter': 40},
        forceRefresh: true,
      ),
      isNull,
    );
    expect(
      pageCounterFromNative(
        {'ok': false, 'stalePageCounter': 40, 'error': 'snmp_timeout'},
        forceRefresh: true,
      ),
      isNull,
    );
    expect(
      pageCounterFromNative(
        {'ok': true, 'stale': false, 'pageCounter': 41},
        forceRefresh: true,
      ),
      41,
    );
  });

  test('failed refreshes after baseline do not verify from cached count', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true, snmpOk: true),
      pageCounterSequence: [100, null, null, null, null, null],
    );
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      counterRetryAttempts: 2,
      reconcileTimeout: const Duration(milliseconds: 80),
    );

    final result = await coordinator.printAndReconcile(
      jobId: 'job-stale',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: ({
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
      }) async {},
    );

    expect(result.outcome, isNot(PrintReconcileOutcome.verified));
    expect(
      result.outcome == PrintReconcileOutcome.reconciliationRequired ||
          result.outcome == PrintReconcileOutcome.unknown,
      isTrue,
    );
  });

  test('later fresh counter increase still verifies after failed refreshes', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true, snmpOk: true),
      pageCounterSequence: [100, null, null, 101],
    );
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      counterRetryAttempts: 2,
      reconcileTimeout: const Duration(seconds: 2),
    );

    final result = await coordinator.printAndReconcile(
      jobId: 'job-recover',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: ({
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
      }) async {},
    );

    expect(result.outcome, PrintReconcileOutcome.verified);
    expect(result.pagesReported, 1);
  });

  test('mid-flight single post-print reading does not false-verify', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true, snmpOk: true),
      // No pre-print baseline; only ever see 101 after send → uncertain.
      pageCounterSequence: [
        null, null, // retries
        101, 101, 101, 101, 101,
      ],
    );
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      counterRetryAttempts: 2,
      reconcileTimeout: const Duration(milliseconds: 120),
    );

    final result = await coordinator.printAndReconcile(
      jobId: 'job-mid-stuck',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: ({
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
      }) async {},
    );

    expect(result.outcome, isNot(PrintReconcileOutcome.verified));
    expect(
      result.outcome == PrintReconcileOutcome.reconciliationRequired ||
          result.outcome == PrintReconcileOutcome.unknown,
      isTrue,
    );
  });

  test('abortAndReset unlocks so next print is not busy', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true, snmpOk: true),
      pageCounter: 10,
    );
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      pollInterval: const Duration(milliseconds: 40),
      reconcileTimeout: const Duration(seconds: 2),
    );

    Future<void> noopReport({
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

    final first = coordinator.printAndReconcile(
      jobId: 'job-abort-a',
      title: 'a.pdf',
      pdfBytes: pdf,
      pagesExpected: 5,
      colorMode: 'bw',
      reportStatus: noopReport,
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
      reportStatus: noopReport,
      // Counter stuck at 10 → will timeout; outcome irrelevant vs busy.
    );
    expect(second.outcome, isNot(PrintReconcileOutcome.busy));
    final firstResult = await first;
    expect(firstResult.reconcileDetail, 'aborted');
  });

  test('busy when a second job starts while locked', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true, snmpOk: true),
      pageCounter: 10,
    );
    final coordinator = buildCoordinator(
      native: native,
      config: snmpConfig(),
      pollInterval: const Duration(milliseconds: 40),
      reconcileTimeout: const Duration(milliseconds: 300),
    );

    Future<void> noopReport({
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

    final first = coordinator.printAndReconcile(
      jobId: 'job-a',
      title: 'a.pdf',
      pdfBytes: pdf,
      pagesExpected: 5,
      colorMode: 'bw',
      reportStatus: noopReport,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final second = await coordinator.printAndReconcile(
      jobId: 'job-b',
      title: 'b.pdf',
      pdfBytes: pdf,
      pagesExpected: 1,
      colorMode: 'bw',
      reportStatus: noopReport,
    );
    expect(second.outcome, PrintReconcileOutcome.busy);
    await first;
  });
}
