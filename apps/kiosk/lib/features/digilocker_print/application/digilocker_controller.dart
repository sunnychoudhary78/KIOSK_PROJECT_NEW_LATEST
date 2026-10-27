import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/printer/application/printer_health_controller.dart';
import 'package:skp_kiosk/services/printer/print_job_support.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/digilocker_print/data/digilocker_print_repository.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';

final digilockerRepositoryProvider = Provider<DigilockerPrintRepository>((ref) {
  return DigilockerPrintRepository(ref.watch(apiClientProvider));
});

enum DigilockerPhase {
  idle,
  awaitingConsent,
  loadingDocs,
  ready,
  preparingPreview,
  previewing,
  printing,
  printResult,
  done,
  error,
}

class DigilockerUiState {
  const DigilockerUiState({
    this.phase = DigilockerPhase.idle,
    this.sessionId,
    this.authorizationUrl,
    this.documents = const [],
    this.message,
    this.error,
    this.previewTitle,
    this.previewBytes,
    this.previewFilePath,
    this.previewJobId,
    this.printConfirmed = false,
    this.printFailures = 0,
    this.paperOut = false,
  });

  final DigilockerPhase phase;
  final String? sessionId;
  final String? authorizationUrl;
  final List<DigilockerDocument> documents;
  final String? message;
  final String? error;
  final String? previewTitle;
  final Uint8List? previewBytes;
  final String? previewFilePath;
  final String? previewJobId;
  final bool printConfirmed;
  final int printFailures;
  final bool paperOut;

  bool get loading =>
      phase == DigilockerPhase.loadingDocs ||
      phase == DigilockerPhase.preparingPreview ||
      phase == DigilockerPhase.printing;
}

class DigilockerController extends Notifier<DigilockerUiState> {
  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const _maxPollAttempts = 150; // ~5 minutes at 2s
  bool _authCallbackSeen = false;
  bool _pollInFlight = false;

  bool _endingSession = false;
  bool _serverCancelled = false;

  @override
  DigilockerUiState build() {
    ref.onDispose(() {
      _pollTimer?.cancel();
      final sessionId = state.sessionId;
      final previewPath = state.previewFilePath;
      final repository = _repository;
      final alreadyCancelled = _serverCancelled;
      unawaited(
        _disposeCleanup(
          repository: repository,
          sessionId: alreadyCancelled ? null : sessionId,
          previewPath: previewPath,
        ),
      );
    });
    return const DigilockerUiState();
  }

  DigilockerPrintRepository get _repository => ref.read(digilockerRepositoryProvider);
  PrintCoordinator get _coordinator => ref.read(printCoordinatorProvider);

  /// Cancel the current DigiLocker flow and clear local session data.
  /// Caller should navigate away (e.g. back to home) after this returns.
  Future<void> endSession() async {
    if (_endingSession) {
      return;
    }
    _endingSession = true;
    try {
      _pollTimer?.cancel();
      _pollTimer = null;
      _authCallbackSeen = false;
      _pollAttempts = 0;
      _pollInFlight = false;

      final sessionId = state.sessionId;
      final previewPath = state.previewFilePath;
      await _deletePreviewFile(previewPath);
      await _cancelServer(sessionId);

      if (ref.mounted) {
        state = const DigilockerUiState();
      }
    } finally {
      _endingSession = false;
    }
  }

  Future<void> _cancelServer(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty || _serverCancelled) {
      return;
    }
    try {
      await _repository.cancelSession(sessionId);
      _serverCancelled = true;
    } catch (_) {}
  }

  Future<void> _deletePreviewFile(String? previewPath) async {
    if (previewPath == null || previewPath.isEmpty) {
      return;
    }
    try {
      final file = File(previewPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _disposeCleanup({
    required DigilockerPrintRepository repository,
    required String? sessionId,
    required String? previewPath,
  }) async {
    if (sessionId != null && sessionId.isNotEmpty) {
      try {
        await repository.cancelSession(sessionId);
      } catch (_) {}
    }
    await _deletePreviewFile(previewPath);
  }

  bool _printingPaused() {
    final reason = ref.read(deviceAuthProvider).printingPausedReason;
    final health = ref.read(printerHealthControllerProvider);
    return reason == 'paper_out' || health.state == 'paper_out' || health.noPaper;
  }

  Future<void> start() async {
    _pollTimer?.cancel();
    if (_printingPaused()) {
      state = const DigilockerUiState(
        phase: DigilockerPhase.error,
        paperOut: true,
        error: 'Out of paper. Printing is paused.',
      );
      return;
    }
    _authCallbackSeen = false;
    _pollInFlight = false;
    _serverCancelled = false;
    state = const DigilockerUiState(phase: DigilockerPhase.loadingDocs);
    try {
      final session = await _repository.startSession();
      state = DigilockerUiState(
        phase: DigilockerPhase.awaitingConsent,
        sessionId: session.id,
        authorizationUrl: session.authorizationUrl,
        message: 'Sign in to DigiLocker below.',
      );
      _startPolling(session.id);
    } catch (error) {
      state = DigilockerUiState(
        phase: DigilockerPhase.error,
        paperOut: error is ApiException && error.code == 'printing_paused',
        error: userFacingError(error),
      );
    }
  }

  /// Called when the in-app WebView reaches the OAuth callback URL.
  void onAuthRedirectCompleted() {
    if (_authCallbackSeen) {
      return;
    }
    _authCallbackSeen = true;
    final sessionId = state.sessionId;
    if (sessionId == null) {
      return;
    }
    state = DigilockerUiState(
      phase: DigilockerPhase.loadingDocs,
      sessionId: sessionId,
      message: 'Finishing DigiLocker sign-in…',
    );
    // Polling continues; also nudge an immediate check.
    unawaited(_pollOnce(sessionId, force: true));
  }

  void onWebViewError(String message) {
    if (state.phase != DigilockerPhase.awaitingConsent) {
      return;
    }
    state = DigilockerUiState(
      phase: DigilockerPhase.awaitingConsent,
      sessionId: state.sessionId,
      authorizationUrl: state.authorizationUrl,
      message: state.message,
      error: message,
    );
  }

  void _startPolling(String sessionId) {
    _pollAttempts = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollOnce(sessionId));
    });
  }

  Future<void> _pollOnce(String sessionId, {bool force = false}) async {
    if (!force &&
        state.phase != DigilockerPhase.awaitingConsent &&
        state.phase != DigilockerPhase.loadingDocs) {
      return;
    }
    // Skip overlapping ticks so slow DigiLocker responses cannot stack
    // concurrent GETs and exhaust the shared API rate-limit budget.
    if (_pollInFlight) {
      return;
    }
    // Only auto-advance from consent/loading after auth.
    if (!force &&
        state.phase == DigilockerPhase.loadingDocs &&
        !_authCallbackSeen &&
        state.documents.isEmpty &&
        state.authorizationUrl != null) {
      // Still waiting for WebView callback; keep polling session status.
    }

    _pollAttempts += 1;
    if (_pollAttempts > _maxPollAttempts) {
      _pollTimer?.cancel();
      state = DigilockerUiState(
        phase: DigilockerPhase.error,
        sessionId: sessionId,
        authorizationUrl: state.authorizationUrl,
        error: 'DigiLocker sign-in timed out. Please try again.',
      );
      return;
    }

    _pollInFlight = true;
    try {
      final session = await _repository.getSession(sessionId);
      if (session.status == 'authorized') {
        _pollTimer?.cancel();
        await _loadDocuments(sessionId);
      } else if (session.status == 'failed' || session.status == 'expired') {
        _pollTimer?.cancel();
        state = DigilockerUiState(
          phase: DigilockerPhase.error,
          sessionId: sessionId,
          authorizationUrl: session.authorizationUrl,
          error: 'DigiLocker session ${session.status}. Please try again.',
        );
      }
    } catch (error) {
      if (_pollAttempts > 5 && state.phase == DigilockerPhase.awaitingConsent) {
        state = DigilockerUiState(
          phase: DigilockerPhase.awaitingConsent,
          sessionId: sessionId,
          authorizationUrl: state.authorizationUrl,
          message: state.message,
          error: userFacingError(error),
        );
      }
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _loadDocuments(String sessionId) async {
    state = DigilockerUiState(
      phase: DigilockerPhase.loadingDocs,
      sessionId: sessionId,
    );
    try {
      final documents = await _repository.listDocuments(sessionId);
      state = DigilockerUiState(
        phase: DigilockerPhase.ready,
        sessionId: sessionId,
        documents: documents,
        message: documents.isEmpty
            ? 'No DigiLocker documents were shared. End session and try again, or check DigiLocker consent.'
            : 'Choose any document to preview.',
      );
    } catch (error) {
      state = DigilockerUiState(
        phase: DigilockerPhase.error,
        sessionId: sessionId,
        error: userFacingError(error),
      );
    }
  }

  /// Downloads the document and opens in-app preview (does not print yet).
  Future<void> preparePreview(String documentId) async {
    final sessionId = state.sessionId;
    if (sessionId == null) {
      return;
    }
    final documents = state.documents;
    final matched = documents.where((d) => d.id == documentId);
    final documentTitle = matched.isEmpty ? null : matched.first.name;
    state = DigilockerUiState(
      phase: DigilockerPhase.preparingPreview,
      sessionId: sessionId,
      documents: documents,
    );
    try {
      final job = await _repository.printDocument(
        sessionId: sessionId,
        documentId: documentId,
        title: documentTitle,
      );
      final jobId = job['id'] as String;
      final title = job['title'] as String? ?? 'document';
      final bytes = await _repository.downloadPrintContent(jobId);

      final dir = Directory(p.join(Directory.systemTemp.path, 'skp_digilocker'));
      await dir.create(recursive: true);
      final filePath = p.join(dir.path, '$jobId.pdf');
      await File(filePath).writeAsBytes(bytes, flush: true);

      state = DigilockerUiState(
        phase: DigilockerPhase.previewing,
        sessionId: sessionId,
        documents: documents,
        previewTitle: title,
        previewBytes: bytes,
        previewFilePath: filePath,
        previewJobId: jobId,
      );
    } catch (error) {
      state = DigilockerUiState(
        phase: DigilockerPhase.error,
        sessionId: sessionId,
        documents: documents,
        error: userFacingError(error),
      );
    }
  }

  Future<void> confirmPrint() async {
    final sessionId = state.sessionId;
    final documents = state.documents;
    final bytes = state.previewBytes;
    final jobId = state.previewJobId;
    final title = state.previewTitle ?? 'document';
    final filePath = state.previewFilePath;
    if (sessionId == null || bytes == null || jobId == null) {
      return;
    }
    final failures = state.printFailures;

    state = DigilockerUiState(
      phase: DigilockerPhase.printing,
      sessionId: sessionId,
      documents: documents,
      previewTitle: title,
      previewBytes: bytes,
      previewFilePath: filePath,
      previewJobId: jobId,
      printFailures: failures,
    );

    try {
      final outcome = await _coordinator.printAndReconcile(
        jobId: jobId,
        title: title,
        pdfBytes: bytes,
        pagesExpected: 1,
        colorMode: 'color',
        holdForRetry: failures == 0,
        reportStatus: _repository.reportStatus,
        onProgress: (message) {
          state = DigilockerUiState(
            phase: DigilockerPhase.printing,
            sessionId: sessionId,
            documents: documents,
            previewTitle: title,
            previewBytes: bytes,
            previewFilePath: filePath,
            previewJobId: jobId,
            printFailures: failures,
            message: message,
          );
        },
      );
      if (outcome.isSuccess || outcome.isUncertain) {
        state = DigilockerUiState(
          phase: DigilockerPhase.printResult,
          sessionId: sessionId,
          documents: documents,
          message: outcome.userMessage,
          printConfirmed: outcome.isSuccess,
          previewJobId: jobId,
        );
      } else if (outcome.reconcileDetail == 'paper_out') {
        state = DigilockerUiState(
          phase: DigilockerPhase.previewing,
          sessionId: sessionId,
          documents: documents,
          previewTitle: title,
          previewBytes: bytes,
          previewFilePath: filePath,
          previewJobId: jobId,
          paperOut: true,
          error: outcome.userMessage,
        );
      } else {
        state = DigilockerUiState(
          phase: DigilockerPhase.previewing,
          sessionId: sessionId,
          documents: documents,
          previewTitle: title,
          previewBytes: bytes,
          previewFilePath: filePath,
          previewJobId: jobId,
          printFailures: failures + 1,
          error: outcome.userMessage,
        );
      }
    } catch (error) {
      state = DigilockerUiState(
        phase: DigilockerPhase.previewing,
        sessionId: sessionId,
        documents: documents,
        previewTitle: title,
        previewBytes: bytes,
        previewFilePath: filePath,
        previewJobId: jobId,
        printFailures: failures + 1,
        error: userFacingError(error),
      );
    }
  }

  Future<void> abandonRetry() async {
    if (state.printFailures != 1 || state.paperOut) return;
    final jobId = state.previewJobId;
    final error = state.error;
    state = DigilockerUiState(
      phase: state.phase,
      sessionId: state.sessionId,
      documents: state.documents,
      message: state.message,
      error: state.error,
      previewTitle: state.previewTitle,
      previewBytes: state.previewBytes,
      previewFilePath: state.previewFilePath,
      previewJobId: state.previewJobId,
      printConfirmed: state.printConfirmed,
      printFailures: 2,
      paperOut: state.paperOut,
    );
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
    final jobId = state.previewJobId;
    if (jobId == null || jobId.isEmpty) return;
    await PrintJobSupport(ref.read(apiClientProvider)).send(
      jobId: jobId,
      message: state.error ?? 'Print failed',
    );
    state = DigilockerUiState(
      phase: state.phase,
      sessionId: state.sessionId,
      documents: state.documents,
      previewTitle: state.previewTitle,
      previewBytes: state.previewBytes,
      previewFilePath: state.previewFilePath,
      previewJobId: jobId,
      printFailures: state.printFailures,
      message: 'We received this. Staff will review.',
    );
  }

  Future<void> reportPagesMissing() async {
    final jobId = state.previewJobId;
    if (jobId == null || jobId.isEmpty) return;
    await PrintJobSupport(ref.read(apiClientProvider)).send(
      jobId: jobId,
      message: 'Visitor says the pages were not received.',
    );
  }

  void backToDocuments() {
    unawaited(abandonRetry());
    final sessionId = state.sessionId;
    if (sessionId == null) {
      return;
    }
    state = DigilockerUiState(
      phase: DigilockerPhase.ready,
      sessionId: sessionId,
      documents: state.documents,
      message: 'Choose any document to preview.',
    );
  }

  void markDoneWithoutPrint() {
    final sessionId = state.sessionId;
    final title = state.previewTitle;
    state = DigilockerUiState(
      phase: DigilockerPhase.done,
      sessionId: sessionId,
      documents: state.documents,
      message: title == null ? 'Done' : 'Previewed $title (not printed)',
    );
  }
}

final digilockerControllerProvider =
    NotifierProvider.autoDispose<DigilockerController, DigilockerUiState>(
  DigilockerController.new,
);
