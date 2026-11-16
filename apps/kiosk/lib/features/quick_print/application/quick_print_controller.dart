import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/printer/application/printer_health_controller.dart';
import 'package:skp_kiosk/services/printer/print_job_support.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/quick_print/data/quick_print_repository.dart';
import 'package:skp_kiosk/features/quick_print/domain/quick_print_session.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';

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
  printResult,
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
    this.activePrintJobId,
    this.printed = false,
    this.printFailures = 0,
    this.paperOut = false,
  });

  final QuickPrintPhase phase;
  final QuickPrintSession? session;
  final QuickPrintClaim? claim;
  final String? message;
  final String? error;
  final QuickPrintDocumentRef? previewDoc;
  final Uint8List? previewBytes;
  final String? activePrintJobId;
  final bool printed;
  final int printFailures;
  final bool paperOut;

  bool get loading =>
      phase == QuickPrintPhase.starting ||
      phase == QuickPrintPhase.claiming ||
      phase == QuickPrintPhase.preparingPreview ||
      phase == QuickPrintPhase.printing;

  List<QuickPrintDocumentRef> get documents => claim?.documents ?? const [];

  bool get hasUnprintedDocuments => claim?.hasUnprinted ?? false;

  int get unprintedCount => documents.where((d) => !d.printed).length;

  String get listPrintLabel => unprintedCount > 1 ? 'Print all' : 'Print';

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
    String? activePrintJobId,
    bool clearActivePrintJobId = false,
    bool? printed,
    int? printFailures,
    bool? paperOut,
  }) {
    return QuickPrintUiState(
      phase: phase ?? this.phase,
      session: clearSession ? null : (session ?? this.session),
      claim: clearClaim ? null : (claim ?? this.claim),
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      previewDoc: clearPreviewDoc ? null : (previewDoc ?? this.previewDoc),
      previewBytes: clearPreviewBytes ? null : (previewBytes ?? this.previewBytes),
      activePrintJobId: clearActivePrintJobId
          ? null
          : (activePrintJobId ?? this.activePrintJobId),
      printed: printed ?? this.printed,
      printFailures: printFailures ?? this.printFailures,
      paperOut: paperOut ?? this.paperOut,
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
  PrintCoordinator get _coordinator => ref.read(printCoordinatorProvider);

  bool _printingPaused() {
    final reason = ref.read(deviceAuthProvider).printingPausedReason;
    final health = ref.read(printerHealthControllerProvider);
    return reason == 'paper_out' || health.state == 'paper_out' || health.noPaper;
  }

  Future<void> start() async {
    _poll?.cancel();
    if (_printingPaused()) {
      state = const QuickPrintUiState(
        phase: QuickPrintPhase.error,
        paperOut: true,
        error: 'Out of paper. Printing is paused.',
      );
      return;
    }
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
      final paused = error is ApiException && error.code == 'printing_paused';
      state = QuickPrintUiState(
        phase: QuickPrintPhase.error,
        paperOut: paused,
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
        message: 'Preview a document or tap Print',
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
    if (document.printed) {
      state = state.copyWith(
        phase: QuickPrintPhase.documents,
        message: 'Select another document or Cancel',
        error: 'That document was already printed',
      );
      return;
    }
    state = state.copyWith(
      phase: QuickPrintPhase.preparingPreview,
      previewDoc: document,
      clearPreviewBytes: true,
      clearError: true,
      clearActivePrintJobId: true,
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
        message: 'Preview a document or tap Print',
      );
    }
  }

  void backToDocuments() {
    unawaited(abandonRetry());
    if (state.claim == null) {
      return;
    }
    final hasPrinted = state.claim!.documents.any((d) => d.printed);
    state = state.copyWith(
      phase: QuickPrintPhase.documents,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      clearError: true,
      printFailures: 0,
      message: hasPrinted
          ? 'Select another document or Cancel'
          : 'Preview a document or tap Print',
    );
  }

  void continueToDocuments() {
    if (state.claim == null) {
      return;
    }
    state = state.copyWith(
      phase: QuickPrintPhase.documents,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      clearError: true,
      printFailures: 0,
      message: 'Select another document or Cancel',
    );
  }

  /// Print all unprinted documents from the list (no preview).
  Future<void> printUnprintedFromList() async {
    final claim = state.claim;
    final session = state.session;
    if (claim == null || state.phase != QuickPrintPhase.documents) {
      return;
    }
    if (_coordinator.isShutterBusy || _printingPaused()) {
      return;
    }
    final queue = claim.documents.where((d) => !d.printed).toList();
    if (queue.isEmpty) {
      return;
    }

    var current = claim;
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
        phase: QuickPrintPhase.printing,
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
          phase: QuickPrintPhase.documents,
          claim: current,
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
        claim: current,
        doc: doc,
        bytes: bytes,
        progressMessage: progress,
      );
      if (step == null) {
        return;
      }
      current = step.updated;
      lastJobId = step.jobId;
      lastSuccess = step.success;
      lastMessage = step.message;
    }

    if (!ref.mounted) return;
    state = state.copyWith(
      phase: QuickPrintPhase.printResult,
      session: session,
      claim: current,
      printed: lastSuccess,
      activePrintJobId: lastJobId,
      message: lastMessage,
      clearError: true,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      printFailures: 0,
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

    final step = await _printOneDocument(
      claim: claim,
      doc: doc,
      bytes: bytes,
      progressMessage: 'Printing…',
    );
    if (step == null) {
      return;
    }
    state = state.copyWith(
      phase: QuickPrintPhase.printResult,
      claim: step.updated,
      printed: step.success,
      activePrintJobId: step.jobId,
      message: step.message,
      clearError: true,
      clearPreviewDoc: true,
      clearPreviewBytes: true,
      printFailures: 0,
    );
  }

  Future<({QuickPrintClaim updated, String jobId, bool success, String? message})?>
      _printOneDocument({
    required QuickPrintClaim claim,
    required QuickPrintDocumentRef doc,
    required Uint8List bytes,
    required String progressMessage,
  }) async {
    try {
      final created = await _repository.createDocumentPrintJob(
        sessionId: claim.sessionId,
        documentId: doc.id,
      );
      final printJob = created['printJob'] as Map<String, dynamic>? ?? created;
      final jobId = printJob['id'] as String;
      state = state.copyWith(
        activePrintJobId: jobId,
        previewDoc: doc,
        previewBytes: bytes,
        phase: QuickPrintPhase.printing,
        message: progressMessage,
      );

      final outcome = await _coordinator.printAndReconcile(
        jobId: jobId,
        title: doc.fileName,
        pdfBytes: bytes,
        pagesExpected: doc.pageCount,
        colorMode: claim.printColorMode,
        holdForRetry: state.printFailures == 0,
        reportStatus: _repository.reportStatus,
        onProgress: (message) {
          if (state.message == message) return;
          state = state.copyWith(
            phase: QuickPrintPhase.printing,
            message: message,
            clearError: true,
          );
        },
      );
      if (outcome.isSuccess || outcome.isUncertain) {
        return (
          updated: claim.withDocumentPrinted(doc.id, printJobId: jobId),
          jobId: jobId,
          success: outcome.isSuccess,
          message: outcome.userMessage,
        );
      }
      if (outcome.reconcileDetail == 'paper_out') {
        state = state.copyWith(
          phase: QuickPrintPhase.previewing,
          previewDoc: doc,
          previewBytes: bytes,
          claim: claim,
          paperOut: true,
          error: outcome.userMessage,
          clearMessage: true,
        );
      } else {
        state = state.copyWith(
          phase: QuickPrintPhase.previewing,
          previewDoc: doc,
          previewBytes: bytes,
          claim: claim,
          printFailures: state.printFailures + 1,
          error: outcome.userMessage,
          clearMessage: true,
        );
      }
      return null;
    } catch (error) {
      state = state.copyWith(
        phase: QuickPrintPhase.previewing,
        previewDoc: doc,
        previewBytes: bytes,
        claim: claim,
        printFailures: state.printFailures + 1,
        error: userFacingError(error),
        clearMessage: true,
      );
      return null;
    }
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
