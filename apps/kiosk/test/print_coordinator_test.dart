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

  test('verified when SNMP page counter advances', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true, snmpOk: true),
      pageCounterSequence: [100, 100, 101],
    );
    final spooler = _FakeSpooler();
    final coordinator = PrintCoordinator(
      spooler: spooler,
      monitor: PrinterMonitor(native: native, config: snmpConfig()),
      pollInterval: const Duration(milliseconds: 20),
      reconcileTimeout: const Duration(seconds: 2),
    );
    final reports = <Map<String, dynamic>>[];

    final result = await coordinator.printAndReconcile(
      jobId: 'job-1',
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
      }) async {
        reports.add({
          'status': status,
          'reconcileStatus': reconcileStatus,
          'pagesReported': pagesReported,
        });
      },
    );

    expect(result.outcome, PrintReconcileOutcome.verified);
    expect(spooler.calls, 1);
    expect(reports.last['status'], 'completed');
    expect(reports.last['reconcileStatus'], 'verified');
  });

  test('reconciliation_required on timeout without page delta', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true, snmpOk: true),
      pageCounter: 50,
    );
    final coordinator = PrintCoordinator(
      spooler: _FakeSpooler(),
      monitor: PrinterMonitor(native: native, config: snmpConfig()),
      pollInterval: const Duration(milliseconds: 20),
      reconcileTimeout: const Duration(milliseconds: 80),
    );
    final reports = <Map<String, dynamic>>[];

    final result = await coordinator.printAndReconcile(
      jobId: 'job-2',
      title: 't.pdf',
      pdfBytes: pdf,
      pagesExpected: 2,
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
      }) async {
        reports.add({
          'status': status,
          'reconcileStatus': reconcileStatus,
          'needsAdminReview': needsAdminReview,
        });
      },
    );

    expect(result.outcome, PrintReconcileOutcome.reconciliationRequired);
    expect(reports.last['status'], 'printing');
    expect(reports.last['reconcileStatus'], 'reconciliation_required');
    expect(reports.last['needsAdminReview'], true);
  });

  test('unknown when SNMP is not configured', () async {
    final native = FakePrinterNative(
      health: const PrinterHealth(state: 'ready', online: true),
    );
    final coordinator = PrintCoordinator(
      spooler: _FakeSpooler(),
      monitor: PrinterMonitor(native: native, config: noSnmpConfig()),
      pollInterval: const Duration(milliseconds: 10),
      reconcileTimeout: const Duration(milliseconds: 50),
    );

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
    );

    expect(result.outcome, PrintReconcileOutcome.unknown);
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
    final coordinator = PrintCoordinator(
      spooler: spooler,
      monitor: PrinterMonitor(native: native, config: snmpConfig()),
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
    final coordinator = PrintCoordinator(
      spooler: _FakeSpooler(),
      monitor: PrinterMonitor(native: native, config: snmpConfig()),
      pollInterval: const Duration(milliseconds: 50),
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
