import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/printer/application/printer_health_controller.dart';
import 'package:skp_kiosk/services/printer/print_job_support.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/otp_print/data/otp_print_repository.dart';
import 'package:skp_kiosk/features/otp_print/domain/otp_redeem_result.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';

final otpPrintRepositoryProvider = Provider<OtpPrintRepository>((ref) {
  return OtpPrintRepository(ref.watch(apiClientProvider));
});

enum OtpPrintPhase {
  enterOtp,
  redeeming,
  documents,
  preparingPreview,
  previewing,
  printing,
  printResult,
  done,
  error,
}

class OtpPrintUiState {
  const OtpPrintUiState({
    this.phase = OtpPrintPhase.enterOtp,
    this.redeemResult,
    this.message,
    this.error,
    this.previewDoc,
    this.previewBytes,
    this.activePrintJobId,
    this.lastPrintedDocumentId,
    this.printed = false,
    this.printFailures = 0,
    this.paperOut = false,
  });

  final OtpPrintPhase phase;
  final OtpRedeemResult? redeemResult;
  final String? message;
  final String? error;
  final OtpDocumentRef? previewDoc;
  final Uint8List? previewBytes;
  /// Job created for the current / last print attempt.
  final String? activePrintJobId;
  final String? lastPrintedDocumentId;
  final bool printed;
  final int printFailures;
  final bool paperOut;

  bool get loading =>
      phase == OtpPrintPhase.redeeming ||
      phase == OtpPrintPhase.preparingPreview ||
      phase == OtpPrintPhase.printing;

  List<OtpDocumentRef> get documents => redeemResult?.documents ?? const [];

  bool get hasUnprintedDocuments => redeemResult?.hasUnprinted ?? false;

  int get unprintedCount =>
      documents.where((d) => !d.printed).length;

  String get listPrintLabel => unprintedCount > 1 ? 'Print all' : 'Print';

  OtpPrintUiState copyWith({
    OtpPrintPhase? phase,
    OtpRedeemResult? redeemResult,
    bool clearRedeemResult = false,
    String? message,
    bool clearMessage = false,
    String? error,
    bool clearError = false,
    OtpDocumentRef? previewDoc,
    bool clearPreviewDoc = false,
    Uint8List? previewBytes,
    bool clearPreviewBytes = false,
    String? activePrintJobId,
    bool clearActivePrintJobId = false,
    String? lastPrintedDocumentId,
    bool clearLastPrintedDocumentId = false,
    bool? printed,
    int? printFailures,
    bool? paperOut,
  }) {
    return OtpPrintUiState(
      phase: phase ?? this.phase,
      redeemResult:
          clearRedeemResult ? null : (redeemResult ?? this.redeemResult),
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      previewDoc: clearPreviewDoc ? null : (previewDoc ?? this.previewDoc),
      previewBytes:
          clearPreviewBytes ? null : (previewBytes ?? this.previewBytes),
      activePrintJobId: clearActivePrintJobId
          ? null
          : (activePrintJobId ?? this.activePrintJobId),
      lastPrintedDocumentId: clearLastPrintedDocumentId
          ? null
          : (lastPrintedDocumentId ?? this.lastPrintedDocumentId),
      printed: printed ?? this.printed,
      printFailures: printFailures ?? this.printFailures,
      paperOut: paperOut ?? this.paperOut,
    );
  }
}

class OtpPrintController extends Notifier<OtpPrintUiState> {
  @override
  OtpPrintUiState build() => const OtpPrintUiState();

  OtpPrintRepository get _repository => ref.read(otpPrintRepositoryProvider);
  PrintCoordinator get _coordinator => ref.read(printCoordinatorProvider);

  Future<void> redeem(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        phase: OtpPrintPhase.error,
        error: 'Enter the OTP from SMS',
      );
      return;
    }
    if (_printingPaused()) {
      state = state.copyWith(
        phase: OtpPrintPhase.error,
        error: 'Out of paper. Printing is paused.',
        paperOut: true,
      );
      return;
    }

    state = state.copyWith(
      phase: OtpPrintPhase.redeeming,
      clearError: true,
      clearMessage: true,
      clearRedeemResult: true,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      printed: false,
    );

    try {
      final result = await _repository.redeem(trimmed);
      if (result.documents.isEmpty) {
        throw StateError('No documents returned for this OTP');
      }
      state = OtpPrintUiState(
        phase: OtpPrintPhase.documents,
        redeemResult: result,
        message: 'Preview a document or tap Print',
      );
    } catch (error) {
      state = state.copyWith(
        phase: OtpPrintPhase.error,
        paperOut: error is ApiException && error.code == 'printing_paused',
        error: userFacingError(error),
        clearRedeemResult: true,
      );
    }
  }

  Future<void> preparePreview(OtpDocumentRef document) async {
    final result = state.redeemResult;
    if (result == null) {
      return;
    }
    if (document.printed) {
      state = state.copyWith(
        phase: OtpPrintPhase.documents,
        message: 'Select another document or Cancel',
        error: 'That document was already printed',
      );
      return;
    }

    state = state.copyWith(
      phase: OtpPrintPhase.preparingPreview,
      previewDoc: document,
      clearPreviewBytes: true,
      clearError: true,
      clearActivePrintJobId: true,
      message: 'Preparing document preview…',
    );

    try {
      final bytes = await _repository.downloadDocument(document.contentPath);
      state = state.copyWith(
        phase: OtpPrintPhase.previewing,
        previewDoc: document,
        previewBytes: bytes,
        clearMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        phase: OtpPrintPhase.documents,
        clearPreviewDoc: true,
        clearPreviewBytes: true,
        error: userFacingError(error),
        message: 'Preview a document or tap Print',
      );
    }
  }

  void backToDocuments() {
    unawaited(abandonRetry());
    if (state.redeemResult == null) {
      reset();
      return;
    }
    final hasPrinted = state.redeemResult!.documents.any((d) => d.printed);
    state = state.copyWith(
      phase: OtpPrintPhase.documents,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      clearError: true,
      printFailures: 0,
      message: hasPrinted
          ? 'Select another document or Cancel'
          : 'Preview a document or tap Print',
    );
  }

  /// Return to the list after a successful print when more docs remain.
  void continueToDocuments() {
    if (state.redeemResult == null) {
      reset();
      return;
    }
    state = state.copyWith(
      phase: OtpPrintPhase.documents,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      clearError: true,
      printFailures: 0,
      message: 'Select another document or Cancel',
    );
  }

  /// Print all unprinted documents from the list (no preview).
  Future<void> printUnprintedFromList() async {
    final result = state.redeemResult;
    if (result == null || state.phase != OtpPrintPhase.documents) {
      return;
    }
    if (_coordinator.isShutterBusy || _printingPaused()) {
      return;
    }
    final queue = result.documents.where((d) => !d.printed).toList();
    if (queue.isEmpty) {
      return;
    }

    var current = result;
    String? lastJobId;
    var lastSuccess = false;
    String? lastMessage;

    for (var i = 0; i < queue.length; i++) {
      if (!ref.mounted) return;
      final doc = queue[i];
      final progress = queue.length == 1
          ? 'Printing…'
          : 'Printing ${i + 1} of ${queue.length}…';
      state = state.copyWith(
        phase: OtpPrintPhase.printing,
        previewDoc: doc,
        clearPreviewBytes: true,
        clearError: true,
        message: progress,
        printFailures: 0,
        paperOut: false,
      );

      late final Uint8List bytes;
      try {
        bytes = await _repository.downloadDocument(doc.contentPath);
      } catch (error) {
        state = state.copyWith(
          phase: OtpPrintPhase.documents,
          redeemResult: current,
          clearPreviewDoc: true,
          clearPreviewBytes: true,
          error: userFacingError(error),
          message: current.documents.any((d) => d.printed)
              ? 'Select another document or Cancel'
              : 'Preview a document or tap Print',
        );
        return;
      }

      state = state.copyWith(previewBytes: bytes, message: progress);
      final step = await _printOneDocument(
        result: current,
        doc: doc,
        bytes: bytes,
        progressMessage: progress,
      );
      if (step == null) {
        return; // failure path already set previewing/retry state
      }
      current = step.updated;
      lastJobId = step.jobId;
      lastSuccess = step.success;
      lastMessage = step.message;
    }

    if (!ref.mounted) return;
    state = state.copyWith(
      phase: OtpPrintPhase.printResult,
      redeemResult: current,
      printed: lastSuccess,
      lastPrintedDocumentId: queue.isEmpty ? null : queue.last.id,
      activePrintJobId: lastJobId,
      message: lastMessage,
      clearError: true,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      printFailures: 0,
    );
  }

  Future<void> confirmPrint() async {
    final result = state.redeemResult;
    final doc = state.previewDoc;
    final bytes = state.previewBytes;
    if (result == null || doc == null || bytes == null) {
      return;
    }

    state = state.copyWith(
      phase: OtpPrintPhase.printing,
      clearError: true,
      message: 'Printing…',
    );

    final step = await _printOneDocument(
      result: result,
      doc: doc,
      bytes: bytes,
      progressMessage: 'Printing…',
    );
    if (step == null) {
      return;
    }
    state = state.copyWith(
      phase: OtpPrintPhase.printResult,
      redeemResult: step.updated,
      printed: step.success,
      lastPrintedDocumentId: doc.id,
      activePrintJobId: step.jobId,
      message: step.message,
      clearError: true,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      printFailures: 0,
    );
  }

  /// Returns null when failure state was already applied (stay on preview/retry).
  Future<({OtpRedeemResult updated, String jobId, bool success, String? message})?>
      _printOneDocument({
    required OtpRedeemResult result,
    required OtpDocumentRef doc,
    required Uint8List bytes,
    required String progressMessage,
  }) async {
    try {
      final created = await _repository.createDocumentPrintJob(
        challengeId: result.challengeId,
        documentId: doc.id,
      );
      final printJob = created['printJob'] as Map<String, dynamic>? ?? created;
      final jobId = printJob['id'] as String;
      state = state.copyWith(
        activePrintJobId: jobId,
        previewDoc: doc,
        previewBytes: bytes,
        phase: OtpPrintPhase.printing,
        message: progressMessage,
      );

      final outcome = await _coordinator.printAndReconcile(
        jobId: jobId,
        title: doc.fileName,
        pdfBytes: bytes,
        pagesExpected: doc.pageCount,
        colorMode: result.printColorMode,
        holdForRetry: state.printFailures == 0,
        reportStatus: _repository.reportStatus,
        onProgress: (message) {
          if (state.message == message) return;
          state = state.copyWith(
            phase: OtpPrintPhase.printing,
            message: message,
            clearError: true,
          );
        },
      );
      if (outcome.isSuccess || outcome.isUncertain) {
        return (
          updated: result.withDocumentPrinted(doc.id, printJobId: jobId),
          jobId: jobId,
          success: outcome.isSuccess,
          message: outcome.userMessage,
        );
      }
      if (outcome.reconcileDetail == 'paper_out') {
        state = state.copyWith(
          phase: OtpPrintPhase.previewing,
          previewDoc: doc,
          previewBytes: bytes,
          redeemResult: result,
          paperOut: true,
          error: outcome.userMessage,
          clearMessage: true,
        );
      } else {
        state = state.copyWith(
          phase: OtpPrintPhase.previewing,
          previewDoc: doc,
          previewBytes: bytes,
          redeemResult: result,
          printFailures: state.printFailures + 1,
          error: outcome.userMessage,
          clearMessage: true,
        );
      }
      return null;
    } catch (error) {
      state = state.copyWith(
        phase: OtpPrintPhase.previewing,
        previewDoc: doc,
        previewBytes: bytes,
        redeemResult: result,
        error: userFacingError(error),
        clearMessage: true,
      );
      return null;
    }
  }

  bool _printingPaused() {
    final reason = ref.read(deviceAuthProvider).printingPausedReason;
    final health = ref.read(printerHealthControllerProvider);
    return reason == 'paper_out' || health.state == 'paper_out' || health.noPaper;
  }

  Future<void> abandonRetry() async {
    if (state.printFailures != 1 || state.paperOut) return;
    final jobId = state.activePrintJobId;
    final error = state.error;
    state = state.copyWith(printFailures: 2);
    try {
      await _coordinator.clearPendingSpoolerWork();
    } catch (_) {}
    if (jobId == null || jobId.isEmpty) return;
    try {
      await _repository.reportStatus(
        jobId: jobId,
        status: 'failed',
        pagesReported: 0,
        errorMessage: error,
      );
    } catch (_) {}
  }

  Future<void> tellStaff() async {
    final jobId = state.activePrintJobId;
    if (jobId == null || jobId.isEmpty) return;
    await PrintJobSupport(ref.read(apiClientProvider)).send(
      jobId: jobId,
      message: state.error ?? 'Print failed',
    );
    state = state.copyWith(message: 'We received this. Staff will review.', clearError: true);
  }

  Future<void> reportPagesMissing() async {
    final jobId = state.activePrintJobId;
    if (jobId == null || jobId.isEmpty) return;
    await PrintJobSupport(ref.read(apiClientProvider)).send(
      jobId: jobId,
      message: 'Visitor says the pages were not received.',
    );
  }

  void reset() {
    state = const OtpPrintUiState();
  }

  @visibleForTesting
  void debugLoadRedeemResult(OtpRedeemResult result) {
    state = OtpPrintUiState(
      phase: OtpPrintPhase.documents,
      redeemResult: result,
      message: 'Preview a document or tap Print',
    );
  }
}

final otpPrintControllerProvider =
    NotifierProvider.autoDispose<OtpPrintController, OtpPrintUiState>(
  OtpPrintController.new,
);
