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
    this.counterRetryAttempts = 5,
    this.counterRetryDelay = const Duration(seconds: 1),
    this.noSnmpGrace = const Duration(seconds: 20),
    Duration? reconcileTimeout,
  })  : _spooler = spooler,
        _monitor = monitor,
        _reconcileTimeout = reconcileTimeout;

  final PrintSpooler _spooler;
  final PrinterMonitor _monitor;
  final Duration pollInterval;
  final int counterRetryAttempts;
  final Duration counterRetryDelay;
  final Duration noSnmpGrace;
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

  Future<int?> _readPageCounterWithRetries({
    void Function(String message)? onProgress,
  }) async {
    int? last;
    for (var i = 0; i < counterRetryAttempts; i++) {
      last = await _monitor.getPageCounter();
      if (last != null) {
        return last;
      }
      if (i < counterRetryAttempts - 1) {
        onProgress?.call('Checking printer…');
        await Future<void>.delayed(counterRetryDelay);
      }
    }
    return last;
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
      counterBefore = await _readPageCounterWithRetries(onProgress: onProgress);
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

    if (!snmp) {
      return _waitWithoutSnmp(
        jobId: jobId,
        reportStatus: reportStatus,
        onProgress: onProgress,
      );
    }

    return _reconcileWithSnmp(
      jobId: jobId,
      expected: expected,
      counterBefore: counterBefore,
      reportStatus: reportStatus,
      onProgress: onProgress,
    );
  }

  Future<PrintReconcileResult> _waitWithoutSnmp({
    required String jobId,
    required PrintJobStatusReporter reportStatus,
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Printer processing…');
    final deadline = DateTime.now().add(noSnmpGrace);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      final health = await _monitor.getHealth();
      if (health.isFatal) {
        await reportStatus(
          jobId: jobId,
          status: 'failed',
          errorMessage: health.userMessage,
          pagesReported: 0,
          reconcileStatus: 'pending',
          reconcileDetail: health.lastErrorCode ?? health.state,
        );
        return PrintReconcileResult(
          outcome: PrintReconcileOutcome.failed,
          userMessage: health.userMessage,
          pagesReported: 0,
          reconcileDetail: health.lastErrorCode ?? health.state,
        );
      }
    }
    await reportStatus(
      jobId: jobId,
      status: 'printing',
      pagesReported: 0,
      reconcileStatus: 'unknown',
      reconcileDetail: 'snmp_not_configured',
      needsAdminReview: true,
    );
    return const PrintReconcileResult(
      outcome: PrintReconcileOutcome.unknown,
      userMessage:
          'Print was sent, but physical completion could not be confirmed. Staff will review.',
      pagesReported: 0,
      reconcileDetail: 'snmp_not_configured',
    );
  }

  Future<PrintReconcileResult> _reconcileWithSnmp({
    required String jobId,
    required int expected,
    required int? counterBefore,
    required PrintJobStatusReporter reportStatus,
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Printer processing…');
    final deadline = DateTime.now().add(reconcileTimeout);
    int? baseline = counterBefore;
    int? counterAfter = counterBefore;
    var pagesReported = 0;
    var sawAnyCounter = counterBefore != null;
    var confirmingAnnounced = false;
    if (baseline != null) {
      onProgress?.call('Confirming print…');
      confirmingAnnounced = true;
    }

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      final health = await _monitor.getHealth();
      final after = await _monitor.getPageCounter();

      if (after != null) {
        sawAnyCounter = true;
        if (baseline == null) {
          // Mid-flight baseline: do not complete yet; wait for further increase.
          baseline = after;
          counterAfter = after;
          if (!confirmingAnnounced) {
            onProgress?.call('Confirming print…');
            confirmingAnnounced = true;
          }
        } else {
          counterAfter = after;
          pagesReported = (after - baseline).clamp(0, 100000);
          if (!confirmingAnnounced) {
            onProgress?.call('Confirming print…');
            confirmingAnnounced = true;
          }
        }
      }

      if (baseline != null && pagesReported >= expected) {
        await reportStatus(
          jobId: jobId,
          status: 'completed',
          pagesReported: pagesReported,
          pageCounterBefore: baseline,
          pageCounterAfter: counterAfter,
          reconcileStatus: 'verified',
          reconcileDetail: 'snmp_page_delta',
        );
        return PrintReconcileResult(
          outcome: PrintReconcileOutcome.verified,
          userMessage: 'Printed successfully',
          pagesReported: pagesReported,
          pageCounterBefore: baseline,
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
            pageCounterBefore: baseline,
            pageCounterAfter: counterAfter,
            reconcileStatus: 'partial',
            reconcileDetail: health.lastErrorCode ?? health.state,
            needsAdminReview: true,
          );
          return PrintReconcileResult(
            outcome: PrintReconcileOutcome.failed,
            userMessage: health.userMessage,
            pagesReported: pagesReported,
            pageCounterBefore: baseline,
            pageCounterAfter: counterAfter,
            reconcileDetail: health.lastErrorCode ?? health.state,
          );
        }
        await reportStatus(
          jobId: jobId,
          status: 'failed',
          errorMessage: health.userMessage,
          pagesReported: 0,
          pageCounterBefore: baseline,
          pageCounterAfter: counterAfter,
          reconcileStatus: 'pending',
          reconcileDetail: health.lastErrorCode ?? health.state,
        );
        return PrintReconcileResult(
          outcome: PrintReconcileOutcome.failed,
          userMessage: health.userMessage,
          pagesReported: 0,
          pageCounterBefore: baseline,
          pageCounterAfter: counterAfter,
          reconcileDetail: health.lastErrorCode ?? health.state,
        );
      }
    }

    if (!sawAnyCounter) {
      await reportStatus(
        jobId: jobId,
        status: 'printing',
        pagesReported: 0,
        pageCounterBefore: baseline,
        pageCounterAfter: counterAfter,
        reconcileStatus: 'unknown',
        reconcileDetail: 'snmp_page_counter_unavailable',
        needsAdminReview: true,
      );
      return PrintReconcileResult(
        outcome: PrintReconcileOutcome.unknown,
        userMessage:
            'Print was sent, but physical completion could not be confirmed. Staff will review.',
        pagesReported: 0,
        pageCounterBefore: baseline,
        pageCounterAfter: counterAfter,
        reconcileDetail: 'snmp_page_counter_unavailable',
      );
    }

    await reportStatus(
      jobId: jobId,
      status: 'printing',
      pagesReported: pagesReported,
      pageCounterBefore: baseline,
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
      pageCounterBefore: baseline,
      pageCounterAfter: counterAfter,
      reconcileDetail: 'timeout',
    );
  }
}
