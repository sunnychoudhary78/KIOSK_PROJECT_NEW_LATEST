import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/services/print_spooler.dart';
import 'package:skp_kiosk/services/printer/print_job_status_reporter.dart';
import 'package:skp_kiosk/services/printer/print_reconcile_result.dart';
import 'package:skp_kiosk/services/printer/printer_monitor.dart';

final printCoordinatorProvider = Provider<PrintCoordinator>((ref) {
  return PrintCoordinator(
    spooler: ref.watch(printSpoolerProvider),
    monitor: ref.watch(printerMonitorProvider),
  );
});

class PrintCoordinator {
  PrintCoordinator({
    required PrintSpooler spooler,
    required PrinterMonitor monitor,
    this.pollInterval = const Duration(seconds: 2),
    Duration? reconcileTimeout,
  })  : _spooler = spooler,
        _monitor = monitor,
        _reconcileTimeout = reconcileTimeout;

  final PrintSpooler _spooler;
  final PrinterMonitor _monitor;
  final Duration pollInterval;
  final Duration? _reconcileTimeout;

  bool _locked = false;

  Duration get reconcileTimeout =>
      _reconcileTimeout ??
      Duration(milliseconds: _monitor.reconcileTimeoutMs);

  /// Exclusive print+reconcile for OTP / Quick Print / DigiLocker.
  Future<PrintReconcileResult> printAndReconcile({
    required String jobId,
    required String title,
    required Uint8List pdfBytes,
    required int pagesExpected,
    required String colorMode,
    required PrintJobStatusReporter reportStatus,
    void Function(String message)? onProgress,
  }) async {
    if (_locked) {
      return const PrintReconcileResult(
        outcome: PrintReconcileOutcome.busy,
        userMessage:
            'Another print job is already running. Please wait and try again.',
      );
    }
    _locked = true;
    try {
      return await _run(
        jobId: jobId,
        title: title,
        pdfBytes: pdfBytes,
        pagesExpected: pagesExpected,
        colorMode: colorMode,
        reportStatus: reportStatus,
        onProgress: onProgress,
      );
    } finally {
      _locked = false;
    }
  }

  Future<PrintReconcileResult> _run({
    required String jobId,
    required String title,
    required Uint8List pdfBytes,
    required int pagesExpected,
    required String colorMode,
    required PrintJobStatusReporter reportStatus,
    void Function(String message)? onProgress,
  }) async {
    final expected = pagesExpected < 1 ? 1 : pagesExpected;
    final snmp = _monitor.snmpConfigured;
    int? counterBefore;

    onProgress?.call('Checking printer…');
    final preHealth = await _monitor.getHealth();
    if (preHealth.isFatal) {
      await reportStatus(
        jobId: jobId,
        status: 'failed',
        errorMessage: preHealth.userMessage,
        pagesReported: 0,
        reconcileStatus: 'pending',
        reconcileDetail: preHealth.lastErrorCode ?? preHealth.state,
      );
      return PrintReconcileResult(
        outcome: PrintReconcileOutcome.failed,
        userMessage: preHealth.userMessage,
        pagesReported: 0,
        reconcileDetail: preHealth.lastErrorCode,
      );
    }

    if (snmp) {
      counterBefore = await _monitor.getPageCounter();
    }

    onProgress?.call('Sending to printer…');
    await reportStatus(
      jobId: jobId,
      status: 'printing',
      pageCounterBefore: counterBefore,
      pagesReported: 0,
      reconcileStatus: 'pending',
    );

    try {
      await _spooler.printDocument(
        jobId: jobId,
        title: title,
        pdfBytes: pdfBytes,
        colorMode: colorMode,
      );
    } catch (error) {
      await reportStatus(
        jobId: jobId,
        status: 'failed',
        errorMessage: error.toString(),
        pagesReported: 0,
        pageCounterBefore: counterBefore,
        reconcileStatus: 'pending',
        reconcileDetail: 'spooler_reject',
      );
      return PrintReconcileResult(
        outcome: PrintReconcileOutcome.failed,
        userMessage: error.toString(),
        pagesReported: 0,
        pageCounterBefore: counterBefore,
        reconcileDetail: 'spooler_reject',
      );
    }

    if (!snmp || counterBefore == null) {
      onProgress?.call('Could not confirm print on the printer…');
      await reportStatus(
        jobId: jobId,
        status: 'printing',
        pageCounterBefore: counterBefore,
        reconcileStatus: 'unknown',
        reconcileDetail: snmp
            ? 'snmp_page_counter_unavailable'
            : 'snmp_not_configured',
        needsAdminReview: true,
      );
      return PrintReconcileResult(
        outcome: PrintReconcileOutcome.unknown,
        userMessage:
            'Print was sent, but physical completion could not be confirmed. Staff will review.',
        pageCounterBefore: counterBefore,
        reconcileDetail:
            snmp ? 'snmp_page_counter_unavailable' : 'snmp_not_configured',
      );
    }

    onProgress?.call('Confirming print…');
    final deadline = DateTime.now().add(reconcileTimeout);
    int? counterAfter = counterBefore;
    int pagesReported = 0;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      final health = await _monitor.getHealth();
      final after = await _monitor.getPageCounter();
      if (after != null) {
        counterAfter = after;
        pagesReported = (after - counterBefore).clamp(0, 100000);
      }

      if (pagesReported >= expected) {
        await reportStatus(
          jobId: jobId,
          status: 'completed',
          pagesReported: pagesReported,
          pageCounterBefore: counterBefore,
          pageCounterAfter: counterAfter,
          reconcileStatus: 'verified',
          reconcileDetail: 'snmp_page_delta',
        );
        return PrintReconcileResult(
          outcome: PrintReconcileOutcome.verified,
          userMessage: 'Printed successfully',
          pagesReported: pagesReported,
          pageCounterBefore: counterBefore,
          pageCounterAfter: counterAfter,
          reconcileDetail: 'snmp_page_delta',
        );
      }

      if (health.isFatal) {
        if (pagesReported > 0) {
          await reportStatus(
            jobId: jobId,
            status: 'failed',
            errorMessage: health.userMessage,
            pagesReported: pagesReported,
            pageCounterBefore: counterBefore,
            pageCounterAfter: counterAfter,
            reconcileStatus: 'partial',
            reconcileDetail: health.lastErrorCode ?? health.state,
            needsAdminReview: true,
          );
          return PrintReconcileResult(
            outcome: PrintReconcileOutcome.failed,
            userMessage: health.userMessage,
            pagesReported: pagesReported,
            pageCounterBefore: counterBefore,
            pageCounterAfter: counterAfter,
            reconcileDetail: health.lastErrorCode ?? health.state,
          );
        }
        await reportStatus(
          jobId: jobId,
          status: 'failed',
          errorMessage: health.userMessage,
          pagesReported: 0,
          pageCounterBefore: counterBefore,
          pageCounterAfter: counterAfter,
          reconcileStatus: 'pending',
          reconcileDetail: health.lastErrorCode ?? health.state,
        );
        return PrintReconcileResult(
          outcome: PrintReconcileOutcome.failed,
          userMessage: health.userMessage,
          pagesReported: 0,
          pageCounterBefore: counterBefore,
          pageCounterAfter: counterAfter,
          reconcileDetail: health.lastErrorCode ?? health.state,
        );
      }
    }

    await reportStatus(
      jobId: jobId,
      status: 'printing',
      pagesReported: pagesReported,
      pageCounterBefore: counterBefore,
      pageCounterAfter: counterAfter,
      reconcileStatus: 'reconciliation_required',
      reconcileDetail:
          'timeout: no SNMP page delta within ${reconcileTimeout.inSeconds}s',
      needsAdminReview: true,
    );
    return PrintReconcileResult(
      outcome: PrintReconcileOutcome.reconciliationRequired,
      userMessage:
          'Print could not be confirmed within ${reconcileTimeout.inMinutes} minutes. Staff will review.',
      pagesReported: pagesReported,
      pageCounterBefore: counterBefore,
      pageCounterAfter: counterAfter,
      reconcileDetail: 'timeout',
    );
  }
}
