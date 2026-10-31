import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/services/print_spooler.dart';
import 'package:skp_kiosk/services/printer/print_job_status_reporter.dart';
import 'package:skp_kiosk/services/printer/print_reconcile_result.dart';
import 'package:skp_kiosk/services/printer/printer_monitor.dart';
import 'package:skp_kiosk/services/printer/usb_page_watch.dart';

final printCoordinatorProvider = Provider<PrintCoordinator>((ref) {
  return PrintCoordinator(
    spooler: ref.watch(printSpoolerProvider),
    monitor: ref.watch(printerMonitorProvider),
    usbPageWatch: ref.watch(usbPageWatchProvider),
  );
});

class PrintCoordinator {
  PrintCoordinator({
    required PrintSpooler spooler,
    required PrinterMonitor monitor,
    this.pollInterval = const Duration(seconds: 2),
    this.counterRetryAttempts = 5,
    this.counterRetryDelay = const Duration(seconds: 1),
    this.usbBaselineGrace = const Duration(seconds: 20),
    UsbPageWatch? usbPageWatch,
    Duration? reconcileTimeout,
  })  : _spooler = spooler,
        _monitor = monitor,
        _usbPageWatch = usbPageWatch ?? UsbPageWatch(),
        _reconcileTimeout = reconcileTimeout;

  final PrintSpooler _spooler;
  final PrinterMonitor _monitor;
  final UsbPageWatch _usbPageWatch;
  final Duration pollInterval;
  final int counterRetryAttempts;
  final Duration counterRetryDelay;
  final Duration usbBaselineGrace;
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
    bool holdForRetry = false,
    void Function(String message)? onProgress,
  }) async {
    final allowHold = holdForRetry;
    Future<void> report({
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
    }) {
      final keep = allowHold &&
          status == 'failed' &&
          (pagesReported ?? 0) == 0 &&
          reconcileDetail != 'paper_out';
      return reportStatus(
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
        holdForRetry: keep ? true : null,
      );
    }
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
        reportStatus: report,
        onProgress: onProgress,
      );
    } finally {
      if (runId == _runId) {
        _locked = false;
      }
    }
  }

  /// Fast USB total. `busy`, a failed snapshot, and a missing total are misses.
  Future<int?> _readUsbPagesOnce() async {
    try {
      final snapshot = await _monitor.getUsbSnapshot(full: false);
      _usbPageWatch.record(snapshot);
      if (!snapshot.ok || snapshot.pagesTotal == null) return null;
      return snapshot.pagesTotal;
    } catch (error) {
      AppLogger.error('PRINTER usb page read failed', error);
      return null;
    }
  }

  /// Prefer a watch sample from the last 5 seconds. Otherwise one fast read
  /// while the compare loop stays off the pipe.
  Future<int?> _readUsbBaseline({
    void Function(String message)? onProgress,
  }) async {
    final cached = _usbPageWatch.freshPages();
    if (cached != null) return cached;
    _usbPageWatch.suppress = true;
    try {
      return _readCounterWithRetries(
        read: () async {
          final published = _usbPageWatch.freshPages();
          if (published != null) return published;
          return _readUsbPagesOnce();
        },
        onProgress: onProgress,
      );
    } finally {
      _usbPageWatch.suppress = false;
    }
  }

  Future<int?> _readCounterWithRetries({
    required Future<int?> Function() read,
    void Function(String message)? onProgress,
  }) async {
    int? last;
    for (var i = 0; i < counterRetryAttempts; i++) {
      last = await read();
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

    onProgress?.call('Checking printer…');
    final preHealth = await _monitor.getHealth();
    if (_isAborted(runId)) {
      return _abortedResult(jobId: jobId, reportStatus: reportStatus);
    }
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

    final usbBefore = await _readUsbBaseline(onProgress: onProgress);
    final useUsb = usbBefore != null;
    final int? counterBefore = usbBefore;
    final source = useUsb ? 'usb' : 'none';
    AppLogger.info(
      'PRINTER reconcile job=$jobId source=$source baseline=$counterBefore expected=$expected',
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

    if (useUsb) {
      return _reconcileCounter(
        runId: runId,
        jobId: jobId,
        expected: expected,
        counterBefore: counterBefore,
        readCounter: () async => _usbPageWatch.latestPages,
        verifiedDetail: 'usb_page_delta',
        unavailableDetail: 'usb_page_counter_unavailable',
        timeoutDetail:
            'timeout: no USB page delta within ${reconcileTimeout.inSeconds}s',
        reportStatus: reportStatus,
        onProgress: onProgress,
      );
    }

    return _waitWithoutUsbBaseline(
      runId: runId,
      jobId: jobId,
      reportStatus: reportStatus,
      onProgress: onProgress,
    );
  }

  Future<PrintReconcileResult> _waitWithoutUsbBaseline({
    required int runId,
    required String jobId,
    required PrintJobStatusReporter reportStatus,
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Printer processing…');
    final deadline = DateTime.now().add(usbBaselineGrace);
    while (DateTime.now().isBefore(deadline)) {
      if (_isAborted(runId)) {
        return _abortedResult(jobId: jobId, reportStatus: reportStatus);
      }
      await Future<void>.delayed(pollInterval);
      final health = await _monitor.getHealth();
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
      reconcileDetail: 'usb_baseline_unavailable',
      needsAdminReview: true,
    );
    return const PrintReconcileResult(
      outcome: PrintReconcileOutcome.unknown,
      userMessage:
          'Print was sent, but physical completion could not be confirmed. Staff will review.',
      pagesReported: 0,
      reconcileDetail: 'usb_baseline_unavailable',
    );
  }

  Future<PrintReconcileResult> _reconcileCounter({
    required int runId,
    required String jobId,
    required int expected,
    required int? counterBefore,
    required Future<int?> Function() readCounter,
    required String verifiedDetail,
    required String unavailableDetail,
    required String timeoutDetail,
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
      // A null read is a miss. USB `busy` and SNMP timeouts both look like this.
      final after = await readCounter();
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
          reconcileDetail: verifiedDetail,
        );
        return PrintReconcileResult(
          outcome: PrintReconcileOutcome.verified,
          userMessage: 'Printed successfully',
          pagesReported: pagesReported,
          pageCounterBefore: baseline,
          pageCounterAfter: counterAfter,
          reconcileDetail: verifiedDetail,
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
        'PRINTER reconcile job=$jobId not verified detail=$unavailableDetail',
      );
      await reportStatus(
        jobId: jobId,
        status: 'printing',
        pagesReported: 0,
        pageCounterBefore: baseline,
        pageCounterAfter: counterAfter,
        reconcileStatus: 'unknown',
        reconcileDetail: unavailableDetail,
        needsAdminReview: true,
      );
      return PrintReconcileResult(
        outcome: PrintReconcileOutcome.unknown,
        userMessage:
            'Print was sent, but physical completion could not be confirmed. Staff will review.',
        pagesReported: 0,
        pageCounterBefore: baseline,
        pageCounterAfter: counterAfter,
        reconcileDetail: unavailableDetail,
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
      reconcileDetail: timeoutDetail,
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
