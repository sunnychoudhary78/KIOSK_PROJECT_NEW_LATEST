import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/otp_print/data/otp_print_repository.dart';
import 'package:skp_kiosk/features/otp_print/domain/otp_redeem_result.dart';
import 'package:skp_kiosk/services/print_spooler.dart';

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
  });

  final OtpPrintPhase phase;
  final OtpRedeemResult? redeemResult;
  final String? message;
  final String? error;
  final OtpDocumentRef? previewDoc;
  final Uint8List? previewBytes;
  final bool printed;

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
    );
  }
}

class OtpPrintController extends Notifier<OtpPrintUiState> {
  @override
  OtpPrintUiState build() => const OtpPrintUiState();

  OtpPrintRepository get _repository => ref.read(otpPrintRepositoryProvider);
  PrintSpooler get _spooler => ref.read(printSpoolerProvider);

  Future<void> redeem(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        phase: OtpPrintPhase.error,
        error: 'Enter the OTP from SMS',
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
        error: error.toString(),
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
        error: error.toString(),
        message: 'Select a document to preview',
      );
    }
  }

  void backToDocuments() {
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
      await _repository.reportStatus(
        jobId: result.printJobId,
        status: 'printing',
      );
      await _spooler.printDocument(
        jobId: result.printJobId,
        title: doc.fileName,
        pdfBytes: bytes,
      );
      await _repository.reportStatus(
        jobId: result.printJobId,
        status: 'completed',
      );
      state = state.copyWith(
        phase: OtpPrintPhase.previewing,
        printed: true,
        message: 'Print sent for ${doc.fileName}',
        clearError: true,
      );
    } catch (error) {
      try {
        await _repository.reportStatus(
          jobId: result.printJobId,
          status: 'failed',
          errorMessage: error.toString(),
        );
      } catch (_) {}
      state = state.copyWith(
        phase: OtpPrintPhase.previewing,
        error: error.toString(),
        clearMessage: true,
      );
    }
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
}

final otpPrintControllerProvider =
    NotifierProvider<OtpPrintController, OtpPrintUiState>(OtpPrintController.new);
