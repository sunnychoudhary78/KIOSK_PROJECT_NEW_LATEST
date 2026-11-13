import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:skp_kiosk/core/logging/diagnostic_categories.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/print_job_support.dart';
import 'package:skp_kiosk/services/printer/print_status_body.dart';

enum ReportPrintPhase {
  idle,
  choosingColorMode,
  choosingPayMethod,
  enteringPhone,
  preparingPreview,
  awaitingPayment,
  previewing,
  printing,
  printResult,
}

class ReportPrintSnapshot {
  const ReportPrintSnapshot({
    this.phase = ReportPrintPhase.idle,
    this.previewTitle,
    this.previewBytes,
    this.previewFilePath,
    this.previewJobId,
    this.pagesExpected = 1,
    this.printFailures = 0,
    this.printConfirmed = false,
    this.paperOut = false,
    this.paymentRequired = false,
    this.amountPaise = 0,
    this.checkoutUrl,
    this.checkoutToken,
    this.qrImageUrl,
    this.chargeRupees = 0,
    this.bwChargeRupees = 0,
    this.colorChargeRupees = 0,
    /// Defaults to color so astrology kundali prints stay color unless overridden.
    this.colorMode = 'color',
    this.phoneProofToken,
    this.phoneDigits = '',
    this.otpDigits = '',
    this.otpSent = false,
    this.phoneBusy = false,
    this.phoneNotice,
    this.message,
    this.error,
  });

  final ReportPrintPhase phase;
  final String? previewTitle;
  final Uint8List? previewBytes;
  final String? previewFilePath;
  final String? previewJobId;
  final int pagesExpected;
  final int printFailures;
  final bool printConfirmed;
  final bool paperOut;
  final bool paymentRequired;
  final int amountPaise;
  final String? checkoutUrl;
  final String? checkoutToken;
  /// Razorpay UPI QR bitmap URL (preferred over [checkoutUrl]).
  final String? qrImageUrl;
  final int chargeRupees;
  final int bwChargeRupees;
  final int colorChargeRupees;
  /// DigiLocker-style print mode: `bw` or `color`.
  final String colorMode;
  final String? phoneProofToken;
  final String phoneDigits;
  final String otpDigits;
  final bool otpSent;
  final bool phoneBusy;
  final String? phoneNotice;
  final String? message;
  final String? error;

  bool get isActive => phase != ReportPrintPhase.idle;

  int get selectedModeChargeRupees =>
      colorMode == 'color' ? colorChargeRupees : bwChargeRupees;

  ReportPrintSnapshot copyWith({
    ReportPrintPhase? phase,
    String? previewTitle,
    Uint8List? previewBytes,
    String? previewFilePath,
    String? previewJobId,
    int? pagesExpected,
    int? printFailures,
    bool? printConfirmed,
    bool? paperOut,
    bool? paymentRequired,
    int? amountPaise,
    String? checkoutUrl,
    bool clearCheckoutUrl = false,
    String? checkoutToken,
    bool clearCheckoutToken = false,
    String? qrImageUrl,
    bool clearQrImageUrl = false,
    int? chargeRupees,
    int? bwChargeRupees,
    int? colorChargeRupees,
    String? colorMode,
    String? phoneProofToken,
    bool clearPhoneProofToken = false,
    String? phoneDigits,
    String? otpDigits,
    bool? otpSent,
    bool? phoneBusy,
    String? phoneNotice,
    bool clearPhoneNotice = false,
    String? message,
    bool clearMessage = false,
    String? error,
    bool clearError = false,
  }) {
    return ReportPrintSnapshot(
      phase: phase ?? this.phase,
      previewTitle: previewTitle ?? this.previewTitle,
      previewBytes: previewBytes ?? this.previewBytes,
      previewFilePath: previewFilePath ?? this.previewFilePath,
      previewJobId: previewJobId ?? this.previewJobId,
      pagesExpected: pagesExpected ?? this.pagesExpected,
      printFailures: printFailures ?? this.printFailures,
      printConfirmed: printConfirmed ?? this.printConfirmed,
      paperOut: paperOut ?? this.paperOut,
      paymentRequired: paymentRequired ?? this.paymentRequired,
      amountPaise: amountPaise ?? this.amountPaise,
      checkoutUrl: clearCheckoutUrl ? null : (checkoutUrl ?? this.checkoutUrl),
      checkoutToken:
          clearCheckoutToken ? null : (checkoutToken ?? this.checkoutToken),
      qrImageUrl: clearQrImageUrl ? null : (qrImageUrl ?? this.qrImageUrl),
      chargeRupees: chargeRupees ?? this.chargeRupees,
      bwChargeRupees: bwChargeRupees ?? this.bwChargeRupees,
      colorChargeRupees: colorChargeRupees ?? this.colorChargeRupees,
      colorMode: colorMode ?? this.colorMode,
      phoneProofToken: clearPhoneProofToken
          ? null
          : (phoneProofToken ?? this.phoneProofToken),
      phoneDigits: phoneDigits ?? this.phoneDigits,
      otpDigits: otpDigits ?? this.otpDigits,
      otpSent: otpSent ?? this.otpSent,
      phoneBusy: phoneBusy ?? this.phoneBusy,
      phoneNotice:
          clearPhoneNotice ? null : (phoneNotice ?? this.phoneNotice),
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ReportPrintSupport {
  ReportPrintSupport({
    required ApiClient api,
    required PrintCoordinator coordinator,
    this.tempFolderName = 'skp_report_print',
    String Function(String jobId)? paymentStatusPath,
  })  : _api = api,
        _coordinator = coordinator,
        _paymentStatusPath = paymentStatusPath ??
            ((jobId) => '/astrology/print-jobs/$jobId/payment');

  final ApiClient _api;
  final PrintCoordinator _coordinator;
  final String tempFolderName;
  final String Function(String jobId) _paymentStatusPath;

  Future<ReportPrintSnapshot> prepare({
    required String createJobPath,
    required Map<String, dynamic> body,
    ReportPrintSnapshot previous = const ReportPrintSnapshot(),
  }) async {
    try {
      final job = await _api.post(createJobPath, body: body);
      final jobId = job['id'] as String;
      final title = job['title'] as String? ?? 'Report';
      final pagesExpected = (job['pagesExpected'] as num?)?.toInt() ??
          (job['pageCount'] as num?)?.toInt() ??
          1;
      final paymentRequired = job['paymentRequired'] == true;
      final amountPaise = (job['amountPaise'] as num?)?.toInt() ?? 0;
      final checkoutUrl = job['checkoutUrl'] as String?;
      final checkoutToken = job['checkoutToken'] as String?;
      final qrImageUrl = job['qrImageUrl'] as String?;
      final bytes = await _api.getBytes('/print-jobs/$jobId/content');

      final dir = Directory(p.join(Directory.systemTemp.path, tempFolderName));
      await dir.create(recursive: true);
      final filePath = p.join(dir.path, '$jobId.pdf');
      await File(filePath).writeAsBytes(bytes, flush: true);

      return ReportPrintSnapshot(
        phase: paymentRequired
            ? ReportPrintPhase.awaitingPayment
            : ReportPrintPhase.previewing,
        previewTitle: title,
        previewBytes: bytes,
        previewFilePath: filePath,
        previewJobId: jobId,
        pagesExpected: pagesExpected,
        printFailures: previous.printFailures,
        paymentRequired: paymentRequired,
        amountPaise: amountPaise,
        checkoutUrl: checkoutUrl,
        checkoutToken: checkoutToken,
        qrImageUrl: qrImageUrl,
        colorMode: previous.colorMode,
        bwChargeRupees: previous.bwChargeRupees,
        colorChargeRupees: previous.colorChargeRupees,
        chargeRupees: previous.chargeRupees,
        phoneProofToken: previous.phoneProofToken,
      );
    } catch (error) {
      final message = userFacingError(error);
      Diag.printerError(
        'printer.prepare_failed',
        message,
        {
          'path': createJobPath,
          if (error is ApiException) 'code': error.code,
        },
      );
      // Stay in an active print phase so the shell shows a failure UI instead of
      // silently bouncing back to the feature result screen.
      return ReportPrintSnapshot(
        phase: ReportPrintPhase.printResult,
        printFailures: previous.printFailures,
        printConfirmed: false,
        message: message,
        error: message,
        paperOut: error is ApiException && error.code == 'printing_paused',
      );
    }
  }

  /// Poll device payment status for a prepared print job.
  Future<ReportPrintSnapshot> pollPayment(ReportPrintSnapshot current) async {
    final jobId = current.previewJobId;
    if (jobId == null ||
        current.phase != ReportPrintPhase.awaitingPayment ||
        !current.paymentRequired) {
      return current;
    }
    try {
      final body = await _api.get(_paymentStatusPath(jobId));
      final status = body['status'] as String? ?? '';
      if (status == 'PAID') {
        return current.copyWith(
          phase: ReportPrintPhase.previewing,
          clearError: true,
          clearMessage: true,
        );
      }
      if (status == 'EXPIRED' || status == 'CANCELLED') {
        return current.copyWith(
          phase: ReportPrintPhase.printResult,
          printConfirmed: false,
          error: 'Payment window expired. Tap Print again.',
          message: 'Payment window expired. Tap Print again.',
        );
      }
      return current;
    } catch (error) {
      return current.copyWith(error: userFacingError(error));
    }
  }

  Future<ReportPrintSnapshot> confirm({
    required ReportPrintSnapshot current,
    void Function(String message)? onProgress,
  }) async {
    final bytes = current.previewBytes;
    final jobId = current.previewJobId;
    final title = current.previewTitle ?? 'Report';
    if (bytes == null || jobId == null) {
      return current;
    }
    final failures = current.printFailures;
    final colorMode =
        current.colorMode == 'bw' || current.colorMode == 'color'
            ? current.colorMode
            : 'color';

    try {
      final outcome = await _coordinator.printAndReconcile(
        jobId: jobId,
        title: title,
        pdfBytes: bytes,
        pagesExpected: current.pagesExpected,
        colorMode: colorMode,
        holdForRetry: failures == 0,
        reportStatus: reportStatus,
        onProgress: onProgress,
      );
      if (outcome.isSuccess || outcome.isUncertain) {
        return ReportPrintSnapshot(
          phase: ReportPrintPhase.printResult,
          previewTitle: title,
          previewBytes: bytes,
          previewFilePath: current.previewFilePath,
          previewJobId: jobId,
          pagesExpected: current.pagesExpected,
          printConfirmed: outcome.isSuccess,
          message: outcome.userMessage,
          paymentRequired: current.paymentRequired,
          amountPaise: current.amountPaise,
        );
      }
      if (outcome.reconcileDetail == 'paper_out') {
        Diag.printerError(
          'printer.paper_out',
          outcome.userMessage,
          {'jobId': jobId, 'detail': 'paper_out'},
        );
        return current.copyWith(
          phase: ReportPrintPhase.previewing,
          paperOut: true,
          error: outcome.userMessage,
          clearMessage: true,
        );
      }
      Diag.printerError(
        'printer.confirm_failed',
        outcome.userMessage,
        {
          'jobId': jobId,
          if (outcome.reconcileDetail != null)
            'detail': outcome.reconcileDetail,
          'failures': failures + 1,
        },
      );
      return current.copyWith(
        phase: ReportPrintPhase.previewing,
        printFailures: failures + 1,
        error: outcome.userMessage,
        clearMessage: true,
      );
    } catch (error) {
      final message = userFacingError(error);
      Diag.printerError(
        'printer.confirm_failed',
        message,
        {'jobId': jobId, 'failures': failures + 1},
      );
      return current.copyWith(
        phase: ReportPrintPhase.previewing,
        printFailures: failures + 1,
        error: message,
        clearMessage: true,
      );
    }
  }

  Future<void> reportStatus({
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
    await _api.patch(
      '/print-jobs/$jobId/status',
      body: printStatusBody(
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
      ),
    );
  }

  Future<ReportPrintSnapshot> abandonRetry(ReportPrintSnapshot current) async {
    if (current.printFailures != 1 || current.paperOut) return current;
    final jobId = current.previewJobId;
    final next = current.copyWith(printFailures: 2);
    try {
      await _coordinator.clearPendingSpoolerWork();
    } catch (_) {}
    if (jobId == null || jobId.isEmpty) return next;
    try {
      await reportStatus(
        jobId: jobId,
        status: 'failed',
        pagesReported: 0,
        errorMessage: current.error,
      );
    } catch (_) {}
    return next;
  }

  Future<ReportPrintSnapshot> tellStaff(
    ReportPrintSnapshot current,
    ApiClient api,
  ) async {
    final jobId = current.previewJobId;
    if (jobId == null || jobId.isEmpty) return current;
    await PrintJobSupport(api).send(
      jobId: jobId,
      message: current.error ?? 'Print failed',
    );
    return current.copyWith(message: 'We received this. Staff will review.');
  }

  Future<void> reportPagesMissing(ReportPrintSnapshot current, ApiClient api) async {
    final jobId = current.previewJobId;
    if (jobId == null || jobId.isEmpty) return;
    await PrintJobSupport(api).send(
      jobId: jobId,
      message: 'Visitor says the pages were not received.',
    );
  }
}
