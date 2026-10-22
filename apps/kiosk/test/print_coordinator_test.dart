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
      // preHealth + retries miss, then poll establishes baseline 100 and delta 101.
      // getHealth also consumes sequence entries during polls.
      pageCounterSequence: [
        null, // preHealth
        null, null, // retries
        null, // first poll health
        100, // first poll counter → baseline
        100, // second poll health
        101, // second poll counter → verified
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
      }) async {},
    );

    expect(result.outcome, PrintReconcileOutcome.failed);
    expect(spooler.calls, 0);
    expect(result.userMessage, contains('jam'));
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
