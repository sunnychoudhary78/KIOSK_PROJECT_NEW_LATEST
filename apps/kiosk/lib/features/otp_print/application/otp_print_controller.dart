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
  final bool printed;
  final int printFailures;
  final bool paperOut;

  bool get loading =>
      phase == OtpPrintPhase.redeeming ||
      phase == OtpPrintPhase.preparingPreview ||
      phase == OtpPrintPhase.printing;

  List<OtpDocumentRef> get documents => redeemResult?.documents ?? const [];

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
        message: 'Select a document to preview',
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

    state = state.copyWith(
      phase: OtpPrintPhase.preparingPreview,
      previewDoc: document,
      clearPreviewBytes: true,
      clearError: true,
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
        message: 'Select a document to preview',
      );
    }
  }

  void backToDocuments() {
    unawaited(abandonRetry());
    if (state.redeemResult == null) {
      reset();
      return;
    }
    state = state.copyWith(
      phase: OtpPrintPhase.documents,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      clearError: true,
      message: 'Select a document to preview',
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

    try {
      final outcome = await _coordinator.printAndReconcile(
        jobId: result.printJobId,
        title: doc.fileName,
        pdfBytes: bytes,
        pagesExpected: doc.pageCount,
        colorMode: result.printColorMode,
        holdForRetry: state.printFailures == 0,
        reportStatus: _repository.reportStatus,
        onProgress: (message) {
          state = state.copyWith(
            phase: OtpPrintPhase.printing,
            message: message,
            clearError: true,
          );
        },
      );
      if (outcome.isSuccess || outcome.isUncertain) {
        state = state.copyWith(
          phase: OtpPrintPhase.printResult,
          printed: outcome.isSuccess,
          message: outcome.userMessage,
          clearError: true,
          clearPreviewDoc: true,
          clearPreviewBytes: true,
        );
      } else if (outcome.reconcileDetail == 'paper_out') {
        state = state.copyWith(
          phase: OtpPrintPhase.previewing,
          paperOut: true,
          error: outcome.userMessage,
          clearMessage: true,
        );
      } else {
        state = state.copyWith(
          phase: OtpPrintPhase.previewing,
          printFailures: state.printFailures + 1,
          error: outcome.userMessage,
          clearMessage: true,
        );
      }
    } catch (error) {
      state = state.copyWith(
        phase: OtpPrintPhase.previewing,
        error: userFacingError(error),
        clearMessage: true,
      );
    }
  }

  bool _printingPaused() {
    final reason = ref.read(deviceAuthProvider).printingPausedReason;
    final health = ref.read(printerHealthControllerProvider);
    return reason == 'paper_out' || health.state == 'paper_out' || health.noPaper;
  }

  Future<void> abandonRetry() async {
    if (state.printFailures != 1 || state.paperOut) return;
    final jobId = state.redeemResult?.printJobId;
    final error = state.error;
    state = state.copyWith(printFailures: 2);
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
    final jobId = state.redeemResult?.printJobId;
    if (jobId == null || jobId.isEmpty) return;
    await PrintJobSupport(ref.read(apiClientProvider)).send(
      jobId: jobId,
      message: state.error ?? 'Print failed',
    );
    state = state.copyWith(message: 'We received this. Staff will review.', clearError: true);
  }

  Future<void> reportPagesMissing() async {
    final jobId = state.redeemResult?.printJobId;
    if (jobId == null || jobId.isEmpty) return;
    await PrintJobSupport(ref.read(apiClientProvider)).send(
      jobId: jobId,
      message: 'Visitor says the pages were not received.',
    );
  }

  void markDoneWithoutPrint() {
    state = state.copyWith(
      phase: OtpPrintPhase.done,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      message: state.printed
          ? 'Finished'
          : 'Done without printing. You can start again with a new OTP.',
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
      message: 'Select a document to preview',
    );
  }
}

final otpPrintControllerProvider =
    NotifierProvider.autoDispose<OtpPrintController, OtpPrintUiState>(
  OtpPrintController.new,
);
