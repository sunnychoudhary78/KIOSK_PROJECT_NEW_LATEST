import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
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
  int _runId = 0;
  bool _abortRequested = false;

  bool get isLocked => _locked;

  Duration get reconcileTimeout =>
      _reconcileTimeout ??
      Duration(milliseconds: _monitor.reconcileTimeoutMs);

  /// Abort in-flight reconcile and clear the exclusive lock (home / visitor reset).
  void abortAndReset() {
    _abortRequested = true;
    _runId++;
    _locked = false;
  }

  bool _isAborted(int runId) => _abortRequested || runId != _runId;

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
    _abortRequested = false;
    final runId = ++_runId;
    try {
      return await _run(
        runId: runId,
        jobId: jobId,
        title: title,
        pdfBytes: pdfBytes,
        pagesExpected: pagesExpected,
        colorMode: colorMode,
        reportStatus: reportStatus,
        onProgress: onProgress,
      );
    } finally {
      if (runId == _runId) {
        _locked = false;
      }
    }
  }

  Future<int?> _readPageCounterWithRetries({
    void Function(String message)? onProgress,
  }) async {
    int? last;
    for (var i = 0; i < counterRetryAttempts; i++) {
      last = await _monitor.getPageCounter(forceRefresh: true);
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

  Future<PrintReconcileResult> _abortedResult({
    required String jobId,
    required PrintJobStatusReporter reportStatus,
    int? pageCounterBefore,
    int? pageCounterAfter,
    int pagesReported = 0,
  }) async {
    await reportStatus(
      jobId: jobId,
      status: 'printing',
      pagesReported: pagesReported,
      pageCounterBefore: pageCounterBefore,
      pageCounterAfter: pageCounterAfter,
      reconcileStatus: 'unknown',
      reconcileDetail: 'aborted',
      needsAdminReview: true,
    );
    return PrintReconcileResult(
      outcome: PrintReconcileOutcome.unknown,
      userMessage: 'Print was cancelled.',
      pagesReported: pagesReported,
      pageCounterBefore: pageCounterBefore,
      pageCounterAfter: pageCounterAfter,
      reconcileDetail: 'aborted',
    );
  }

  Future<PrintReconcileResult> _run({
    required int runId,
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
    if (_isAborted(runId)) {
      return _abortedResult(jobId: jobId, reportStatus: reportStatus);
    }
    // Starting a job: full isFatal (incl. sustained SNMP unreachable).
    if (preHealth.isFatal) {
      final preDetail = preHealth.noPaper
          ? 'paper_out'
          : (preHealth.jammed
              ? 'jam'
              : (preHealth.lastErrorCode ?? preHealth.state));
      await reportStatus(
        jobId: jobId,
        status: 'failed',
        errorMessage: preHealth.userMessage,
        pagesReported: 0,
        reconcileStatus: 'pending',
        reconcileDetail: preDetail,
      );
      return PrintReconcileResult(
        outcome: PrintReconcileOutcome.failed,
        userMessage: preHealth.userMessage,
        pagesReported: 0,
        reconcileDetail: preDetail,
      );
    }

    if (snmp) {
      counterBefore = await _readPageCounterWithRetries(onProgress: onProgress);
    }
    AppLogger.info(
      'PRINTER reconcile job=$jobId baseline=$counterBefore expected=$expected',
    );
    if (_isAborted(runId)) {
      return _abortedResult(
        jobId: jobId,
        reportStatus: reportStatus,
        pageCounterBefore: counterBefore,
      );
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

    if (_isAborted(runId)) {
      return _abortedResult(
        jobId: jobId,
        reportStatus: reportStatus,
        pageCounterBefore: counterBefore,
      );
    }

    if (!snmp) {
      return _waitWithoutSnmp(
        runId: runId,
        jobId: jobId,
        reportStatus: reportStatus,
        onProgress: onProgress,
      );
    }

    return _reconcileWithSnmp(
      runId: runId,
      jobId: jobId,
      expected: expected,
      counterBefore: counterBefore,
      reportStatus: reportStatus,
      onProgress: onProgress,
    );
  }

  Future<PrintReconcileResult> _waitWithoutSnmp({
    required int runId,
    required String jobId,
    required PrintJobStatusReporter reportStatus,
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Printer processing…');
    final deadline = DateTime.now().add(noSnmpGrace);
    while (DateTime.now().isBefore(deadline)) {
      if (_isAborted(runId)) {
        return _abortedResult(jobId: jobId, reportStatus: reportStatus);
      }
      await Future<void>.delayed(pollInterval);
      final health = await _monitor.getHealth();
      // Mid-wait without SNMP: physical fatals only.
      if (health.isPhysicalFatal) {
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
    required int runId,
    required String jobId,
    required int expected,
    required int? counterBefore,
    required PrintJobStatusReporter reportStatus,
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Printer processing…');
    final deadline = DateTime.now().add(reconcileTimeout);
    // Pre-print baseline when known. Mid-flight: first post-send reading is a
    // provisional watermark only — verify only after a later reading rises.
    int? baseline = counterBefore;
    final hadPrePrintBaseline = counterBefore != null;
    int? provisionalWatermark;
    int? counterAfter = counterBefore;
    var pagesReported = 0;
    var sawAnyCounter = counterBefore != null;
    var confirmingAnnounced = false;
    if (baseline != null) {
      onProgress?.call('Confirming print…');
      confirmingAnnounced = true;
    }

    while (DateTime.now().isBefore(deadline)) {
      if (_isAborted(runId)) {
        return _abortedResult(
          jobId: jobId,
          reportStatus: reportStatus,
          pageCounterBefore: baseline ?? provisionalWatermark,
          pageCounterAfter: counterAfter,
          pagesReported: pagesReported,
        );
      }
      await Future<void>.delayed(pollInterval);
      if (_isAborted(runId)) {
        return _abortedResult(
          jobId: jobId,
          reportStatus: reportStatus,
          pageCounterBefore: baseline ?? provisionalWatermark,
          pageCounterAfter: counterAfter,
          pagesReported: pagesReported,
        );
      }

      final health = await _monitor.getHealth();
      // Always force-refresh during reconcile (lab: timeouts leave stale cache).
      final after = await _monitor.getPageCounter(forceRefresh: true);
      if (after == null) {
        AppLogger.info('PRINTER reconcile job=$jobId counter refresh failed');
      } else {
        AppLogger.info(
          'PRINTER reconcile job=$jobId counter=$after baseline=${baseline ?? provisionalWatermark}',
        );
      }

      if (!confirmingAnnounced) {
        final label = health.hrPrinterStatusLabel;
        if (label == 'printing' || label == 'warmup' || health.isBusy) {
          onProgress?.call('Printer processing…');
        }
      }

      if (after != null) {
        sawAnyCounter = true;
        counterAfter = after;
        if (!hadPrePrintBaseline && baseline == null) {
          if (provisionalWatermark == null) {
            provisionalWatermark = after;
            if (!confirmingAnnounced) {
              onProgress?.call('Confirming print…');
              confirmingAnnounced = true;
            }
          } else if (after > provisionalWatermark) {
            baseline = provisionalWatermark;
            pagesReported = (after - provisionalWatermark).clamp(0, 100000);
          }
        } else if (baseline != null) {
          pagesReported = (after - baseline).clamp(0, 100000);
          if (!confirmingAnnounced) {
            onProgress?.call('Confirming print…');
            confirmingAnnounced = true;
          }
        }
      }

      // Verified ONLY on lifetime page Δ under exclusive lock.
      if (baseline != null && pagesReported >= expected) {
        AppLogger.info(
          'PRINTER reconcile job=$jobId verified delta=$pagesReported expected=$expected',
        );
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

      // Physical fatals only — SNMP blips are expected during Brother print.
      if (health.isPhysicalFatal) {
        final detail = health.noPaper
            ? 'paper_out'
            : (health.jammed
                ? 'jam'
                : (health.lastErrorCode ?? health.state));
        if (pagesReported > 0) {
          await reportStatus(
            jobId: jobId,
            status: 'failed',
            errorMessage: health.userMessage,
            pagesReported: pagesReported,
            pageCounterBefore: baseline,
            pageCounterAfter: counterAfter,
            reconcileStatus: 'partial',
            reconcileDetail: detail,
            needsAdminReview: true,
          );
          return PrintReconcileResult(
            outcome: PrintReconcileOutcome.failed,
            userMessage: health.userMessage,
            pagesReported: pagesReported,
            pageCounterBefore: baseline,
            pageCounterAfter: counterAfter,
            reconcileDetail: detail,
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
          reconcileDetail: detail,
        );
        return PrintReconcileResult(
          outcome: PrintReconcileOutcome.failed,
          userMessage: health.userMessage,
          pagesReported: 0,
          pageCounterBefore: baseline,
          pageCounterAfter: counterAfter,
          reconcileDetail: detail,
        );
      }
    }

    if (!sawAnyCounter) {
      AppLogger.info(
        'PRINTER reconcile job=$jobId not verified detail=snmp_page_counter_unavailable',
      );
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

    AppLogger.info(
      'PRINTER reconcile job=$jobId not verified delta=$pagesReported expected=$expected detail=timeout',
    );
    await reportStatus(
      jobId: jobId,
      status: 'printing',
      pagesReported: pagesReported,
      pageCounterBefore: baseline ?? provisionalWatermark,
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
      pageCounterBefore: baseline ?? provisionalWatermark,
      pageCounterAfter: counterAfter,
      reconcileDetail: 'timeout',
    );
  }
}
