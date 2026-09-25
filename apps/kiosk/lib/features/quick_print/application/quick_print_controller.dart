import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/quick_print/data/quick_print_repository.dart';
import 'package:skp_kiosk/features/quick_print/domain/quick_print_session.dart';
import 'package:skp_kiosk/services/print_spooler.dart';

final quickPrintRepositoryProvider = Provider<QuickPrintRepository>((ref) {
  return QuickPrintRepository(ref.watch(apiClientProvider));
});

enum QuickPrintPhase {
  starting,
  waiting,
  claiming,
  documents,
  preparingPreview,
  previewing,
  printing,
  done,
  error,
}

class QuickPrintUiState {
  const QuickPrintUiState({
    this.phase = QuickPrintPhase.starting,
    this.session,
    this.claim,
    this.message,
    this.error,
    this.previewDoc,
    this.previewBytes,
    this.printed = false,
  });

  final QuickPrintPhase phase;
  final QuickPrintSession? session;
  final QuickPrintClaim? claim;
  final String? message;
  final String? error;
  final QuickPrintDocumentRef? previewDoc;
  final Uint8List? previewBytes;
  final bool printed;

  bool get loading =>
      phase == QuickPrintPhase.starting ||
      phase == QuickPrintPhase.claiming ||
      phase == QuickPrintPhase.preparingPreview ||
      phase == QuickPrintPhase.printing;

  List<QuickPrintDocumentRef> get documents => claim?.documents ?? const [];

  QuickPrintUiState copyWith({
    QuickPrintPhase? phase,
    QuickPrintSession? session,
    bool clearSession = false,
    QuickPrintClaim? claim,
    bool clearClaim = false,
    String? message,
    bool clearMessage = false,
    String? error,
    bool clearError = false,
    QuickPrintDocumentRef? previewDoc,
    bool clearPreviewDoc = false,
    Uint8List? previewBytes,
    bool clearPreviewBytes = false,
    bool? printed,
  }) {
    return QuickPrintUiState(
      phase: phase ?? this.phase,
      session: clearSession ? null : (session ?? this.session),
      claim: clearClaim ? null : (claim ?? this.claim),
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      previewDoc: clearPreviewDoc ? null : (previewDoc ?? this.previewDoc),
      previewBytes: clearPreviewBytes ? null : (previewBytes ?? this.previewBytes),
      printed: printed ?? this.printed,
    );
  }
}

class QuickPrintController extends Notifier<QuickPrintUiState> {
  Timer? _poll;

  @override
  QuickPrintUiState build() {
    ref.onDispose(() {
      _poll?.cancel();
    });
    return const QuickPrintUiState();
  }

  QuickPrintRepository get _repository => ref.read(quickPrintRepositoryProvider);
  PrintSpooler get _spooler => ref.read(printSpoolerProvider);

  Future<void> start() async {
    _poll?.cancel();
    state = const QuickPrintUiState(phase: QuickPrintPhase.starting);
    try {
      final session = await _repository.createSession();
      state = QuickPrintUiState(
        phase: QuickPrintPhase.waiting,
        session: session,
        message: 'Scan the QR with your phone',
      );
      _poll = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_tick());
      });
    } catch (error) {
      state = QuickPrintUiState(
        phase: QuickPrintPhase.error,
        error: userFacingError(error),
      );
    }
  }

  Future<void> _tick() async {
    final session = state.session;
    if (session == null || state.phase != QuickPrintPhase.waiting) {
      return;
    }
    try {
      final next = await _repository.getSession(session.id, publicUrl: session.publicUrl);
      if (next.isReady) {
        _poll?.cancel();
        await _claim(next);
        return;
      }
      if (next.isTerminal) {
        _poll?.cancel();
        state = state.copyWith(
          phase: QuickPrintPhase.error,
          session: next,
          error: next.status == 'cancelled'
              ? 'This session was cancelled.'
              : 'This session has expired. Start again.',
        );
        return;
      }
      state = state.copyWith(session: next);
    } catch (error) {
      final message = userFacingError(error);
      final expired = error is ApiException &&
          (error.code == 'session_expired' || error.code == 'session_cancelled');
      if (expired) {
        _poll?.cancel();
        state = state.copyWith(phase: QuickPrintPhase.error, error: message);
        return;
      }
      state = state.copyWith(error: message);
    }
  }

  Future<void> _claim(QuickPrintSession session) async {
    state = state.copyWith(
      phase: QuickPrintPhase.claiming,
      session: session,
      message: 'Fetching documents…',
      clearError: true,
    );
    try {
      final claim = await _repository.claim(session.id);
      if (claim.documents.isEmpty) {
        throw StateError('No documents were uploaded');
      }
      state = QuickPrintUiState(
        phase: QuickPrintPhase.documents,
        session: session,
        claim: claim,
        message: 'Select a document to preview',
      );
    } catch (error) {
      state = state.copyWith(
        phase: QuickPrintPhase.error,
        error: userFacingError(error),
      );
    }
  }

  Future<void> preparePreview(QuickPrintDocumentRef document) async {
    final claim = state.claim;
    if (claim == null) return;
    state = state.copyWith(
      phase: QuickPrintPhase.preparingPreview,
      previewDoc: document,
      clearPreviewBytes: true,
      clearError: true,
      message: 'Preparing document preview…',
    );
    try {
      final bytes = await _repository.downloadDocument(document.contentPath);
      state = state.copyWith(
        phase: QuickPrintPhase.previewing,
        previewDoc: document,
        previewBytes: bytes,
        clearMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        phase: QuickPrintPhase.documents,
        clearPreviewDoc: true,
        clearPreviewBytes: true,
        error: userFacingError(error),
        message: 'Select a document to preview',
      );
    }
  }

  void backToDocuments() {
    if (state.claim == null) {
      return;
    }
    state = state.copyWith(
      phase: QuickPrintPhase.documents,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      clearError: true,
      message: 'Select a document to preview',
    );
  }

  Future<void> confirmPrint() async {
    final claim = state.claim;
    final doc = state.previewDoc;
    final bytes = state.previewBytes;
    if (claim == null || doc == null || bytes == null) {
      return;
    }
    state = state.copyWith(
      phase: QuickPrintPhase.printing,
      clearError: true,
      message: 'Printing…',
    );
    try {
      await _repository.reportStatus(jobId: claim.printJobId, status: 'printing');
      await _spooler.printDocument(
        jobId: claim.printJobId,
        title: doc.fileName,
        pdfBytes: bytes,
        colorMode: claim.printColorMode,
      );
      await _repository.reportStatus(jobId: claim.printJobId, status: 'completed');
      state = state.copyWith(
        phase: QuickPrintPhase.previewing,
        printed: true,
        message: 'Print sent for ${doc.fileName}',
        clearError: true,
      );
    } catch (error) {
      try {
        await _repository.reportStatus(
          jobId: claim.printJobId,
          status: 'failed',
          errorMessage: error.toString(),
        );
      } catch (_) {}
      state = state.copyWith(
        phase: QuickPrintPhase.previewing,
        error: userFacingError(error),
        clearMessage: true,
      );
    }
  }

  void markDoneWithoutPrint() {
    state = state.copyWith(
      phase: QuickPrintPhase.done,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      message: state.printed ? 'Finished' : 'Done without printing.',
    );
  }

  Future<void> reset() async {
    _poll?.cancel();
    final session = state.session;
    if (session != null && !session.isTerminal && state.claim == null) {
      try {
        await _repository.cancel(session.id);
      } catch (_) {}
    }
    state = const QuickPrintUiState();
  }
}

final quickPrintControllerProvider =
    NotifierProvider.autoDispose<QuickPrintController, QuickPrintUiState>(
  QuickPrintController.new,
);
