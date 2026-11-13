import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/digilocker_print/data/digilocker_print_repository.dart';
import 'package:skp_kiosk/features/printer/application/printer_health_controller.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/print_job_support.dart';

final digilockerRepositoryProvider = Provider<DigilockerPrintRepository>((ref) {
  return DigilockerPrintRepository(ref.watch(apiClientProvider));
});

enum DigilockerPhase {
  idle,
  awaitingConsent,
  loadingDocs,
  ready,
  choosingPrintOptions,
  enteringPhone,
  preparingPreview,
  awaitingPayment,
  previewing,
  printing,
  printResult,
  done,
  error,
}

class DigilockerQuotaSummary {
  const DigilockerQuotaSummary({
    required this.freeEligible,
    required this.society,
    required this.colorMode,
    this.remaining,
    this.message,
    this.phoneProofToken,
  });

  final bool freeEligible;
  final bool society;
  final String colorMode;
  final int? remaining;
  final String? message;
  final String? phoneProofToken;

  String get modeLabel => colorMode == 'color' ? 'color' : 'B&W';

  String get remainingLabel {
    if (!society) return 'Not on society free list';
    if (remaining == null) return 'Unavailable';
    return '$remaining free $modeLabel page${remaining == 1 ? '' : 's'} left';
  }

  String get printCostLine => freeEligible
      ? 'This DigiLocker print is free for you (uses free $modeLabel pages).'
      : 'This DigiLocker print requires payment.';
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
    this.pendingDocumentId,
    this.pendingDocumentTitle,
    this.colorMode,
    this.bwChargeRupees = 0,
    this.colorChargeRupees = 0,
    this.paymentRequired = false,
    this.amountPaise = 0,
    this.qrImageUrl,
    this.pagesExpected = 1,
    this.printColorMode = 'bw',
    this.phoneDigits = '',
    this.otpDigits = '',
    this.otpSent = false,
    this.phoneBusy = false,
    this.phoneNotice,
    this.pendingPhoneProofToken,
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
  final String? pendingDocumentId;
  final String? pendingDocumentTitle;
  final String? colorMode;
  final int bwChargeRupees;
  final int colorChargeRupees;
  final bool paymentRequired;
  final int amountPaise;
  final String? qrImageUrl;
  final int pagesExpected;
  final String printColorMode;
  final String phoneDigits;
  final String otpDigits;
  final bool otpSent;
  final bool phoneBusy;
  final String? phoneNotice;
  final String? pendingPhoneProofToken;

  int get selectedModeChargeRupees {
    if (colorMode == 'color') return colorChargeRupees;
    return bwChargeRupees;
  }

  bool get loading =>
      phase == DigilockerPhase.loadingDocs ||
      phase == DigilockerPhase.preparingPreview ||
      phase == DigilockerPhase.printing ||
      phoneBusy;

  DigilockerUiState copyWith({
    DigilockerPhase? phase,
    String? sessionId,
    bool clearSessionId = false,
    String? authorizationUrl,
    bool clearAuthorizationUrl = false,
    List<DigilockerDocument>? documents,
    String? message,
    bool clearMessage = false,
    String? error,
    bool clearError = false,
    String? previewTitle,
    bool clearPreviewTitle = false,
    Uint8List? previewBytes,
    bool clearPreviewBytes = false,
    String? previewFilePath,
    bool clearPreviewFilePath = false,
    String? previewJobId,
    bool clearPreviewJobId = false,
    bool? printConfirmed,
    int? printFailures,
    bool? paperOut,
    String? pendingDocumentId,
    bool clearPendingDocumentId = false,
    String? pendingDocumentTitle,
    bool clearPendingDocumentTitle = false,
    String? colorMode,
    bool clearColorMode = false,
    int? bwChargeRupees,
    int? colorChargeRupees,
    bool? paymentRequired,
    int? amountPaise,
    String? qrImageUrl,
    bool clearQrImageUrl = false,
    int? pagesExpected,
    String? printColorMode,
    String? phoneDigits,
    String? otpDigits,
    bool? otpSent,
    bool? phoneBusy,
    String? phoneNotice,
    bool clearPhoneNotice = false,
    String? pendingPhoneProofToken,
    bool clearPendingPhoneProofToken = false,
  }) {
    return DigilockerUiState(
      phase: phase ?? this.phase,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      authorizationUrl: clearAuthorizationUrl
          ? null
          : (authorizationUrl ?? this.authorizationUrl),
      documents: documents ?? this.documents,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      previewTitle:
          clearPreviewTitle ? null : (previewTitle ?? this.previewTitle),
      previewBytes:
          clearPreviewBytes ? null : (previewBytes ?? this.previewBytes),
      previewFilePath: clearPreviewFilePath
          ? null
          : (previewFilePath ?? this.previewFilePath),
      previewJobId:
          clearPreviewJobId ? null : (previewJobId ?? this.previewJobId),
      printConfirmed: printConfirmed ?? this.printConfirmed,
      printFailures: printFailures ?? this.printFailures,
      paperOut: paperOut ?? this.paperOut,
      pendingDocumentId: clearPendingDocumentId
          ? null
          : (pendingDocumentId ?? this.pendingDocumentId),
      pendingDocumentTitle: clearPendingDocumentTitle
          ? null
          : (pendingDocumentTitle ?? this.pendingDocumentTitle),
      colorMode: clearColorMode ? null : (colorMode ?? this.colorMode),
      bwChargeRupees: bwChargeRupees ?? this.bwChargeRupees,
      colorChargeRupees: colorChargeRupees ?? this.colorChargeRupees,
      paymentRequired: paymentRequired ?? this.paymentRequired,
      amountPaise: amountPaise ?? this.amountPaise,
      qrImageUrl: clearQrImageUrl ? null : (qrImageUrl ?? this.qrImageUrl),
      pagesExpected: pagesExpected ?? this.pagesExpected,
      printColorMode: printColorMode ?? this.printColorMode,
      phoneDigits: phoneDigits ?? this.phoneDigits,
      otpDigits: otpDigits ?? this.otpDigits,
      otpSent: otpSent ?? this.otpSent,
      phoneBusy: phoneBusy ?? this.phoneBusy,
      phoneNotice:
          clearPhoneNotice ? null : (phoneNotice ?? this.phoneNotice),
      pendingPhoneProofToken: clearPendingPhoneProofToken
          ? null
          : (pendingPhoneProofToken ?? this.pendingPhoneProofToken),
    );
  }
}

class DigilockerController extends Notifier<DigilockerUiState> {
  Timer? _pollTimer;
  Timer? _paymentPoll;
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
      _stopPaymentPoll();
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

  DigilockerPrintRepository get _repository =>
      ref.read(digilockerRepositoryProvider);
  PrintCoordinator get _coordinator => ref.read(printCoordinatorProvider);

  void _stopPaymentPoll() {
    _paymentPoll?.cancel();
    _paymentPoll = null;
  }

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
      _stopPaymentPoll();
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
    _stopPaymentPoll();
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
    if (_pollInFlight) {
      return;
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
            : 'Choose any document to print.',
      );
    } catch (error) {
      state = DigilockerUiState(
        phase: DigilockerPhase.error,
        sessionId: sessionId,
        error: userFacingError(error),
      );
    }
  }

  /// Starts combined print-options flow for a document.
  Future<void> beginPrintFlow(String documentId) async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.phase != DigilockerPhase.ready) {
      return;
    }
    final matched = state.documents.where((d) => d.id == documentId);
    final documentTitle = matched.isEmpty ? null : matched.first.name;
    state = state.copyWith(
      phase: DigilockerPhase.choosingPrintOptions,
      pendingDocumentId: documentId,
      pendingDocumentTitle: documentTitle,
      colorMode: 'bw',
      printColorMode: 'bw',
      clearError: true,
      clearMessage: true,
      clearPhoneNotice: true,
      clearPendingPhoneProofToken: true,
      otpSent: false,
      otpDigits: '',
      phoneBusy: false,
    );
    try {
      final options = await _repository.printOptions();
      if (!ref.mounted) return;
      state = state.copyWith(
        bwChargeRupees: (options['bwChargeRupees'] as num?)?.toInt() ?? 0,
        colorChargeRupees: (options['colorChargeRupees'] as num?)?.toInt() ?? 0,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: DigilockerPhase.ready,
        clearPendingDocumentId: true,
        clearPendingDocumentTitle: true,
        error: userFacingError(error),
      );
    }
  }

  void setColorMode(String mode) {
    if (state.phase != DigilockerPhase.choosingPrintOptions) return;
    if (mode != 'bw' && mode != 'color') return;
    state = state.copyWith(
      colorMode: mode,
      printColorMode: mode,
      clearError: true,
      clearPhoneNotice: true,
    );
  }

  Future<void> continueFreePrint() async {
    if (state.phase != DigilockerPhase.choosingPrintOptions) return;
    if (state.selectedModeChargeRupees > 0) return;
    await _runPreparePrint();
  }

  Future<void> choosePhoneQuota() async {
    if (state.phase != DigilockerPhase.choosingPrintOptions) return;
    if (state.selectedModeChargeRupees <= 0) return;
    state = state.copyWith(
      phase: DigilockerPhase.enteringPhone,
      otpSent: false,
      otpDigits: '',
      clearError: true,
      clearPhoneNotice: true,
    );
  }

  Future<void> choosePayDirect() async {
    if (state.phase != DigilockerPhase.choosingPrintOptions &&
        state.phase != DigilockerPhase.enteringPhone) {
      return;
    }
    await _runPreparePrint();
  }

  void setPrintPhoneDigits(String value) {
    state = state.copyWith(
      phoneDigits: value.replaceAll(RegExp(r'\D'), ''),
    );
  }

  void setPrintOtpDigits(String value) {
    state = state.copyWith(
      otpDigits: value.replaceAll(RegExp(r'\D'), ''),
    );
  }

  Future<void> requestPrintPhoneOtp() async {
    if (state.phase != DigilockerPhase.enteringPhone) return;
    final phone = state.phoneDigits;
    if (phone.length < 10) {
      state = state.copyWith(error: 'Enter a valid 10-digit mobile number');
      return;
    }
    state = state.copyWith(phoneBusy: true, clearError: true);
    try {
      await _repository.requestPhoneOtp(phone);
      if (!ref.mounted) return;
      state = state.copyWith(
        phoneBusy: false,
        otpSent: true,
        otpDigits: '',
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phoneBusy: false,
        error: userFacingError(error),
      );
    }
  }

  Future<DigilockerQuotaSummary?> verifyPrintPhoneOtp() async {
    if (state.phase != DigilockerPhase.enteringPhone) return null;
    final phone = state.phoneDigits;
    final otp = state.otpDigits;
    final colorMode = state.colorMode;
    if (colorMode == null) return null;
    if (otp.length < 4) {
      state = state.copyWith(error: 'Enter the OTP sent to your phone');
      return null;
    }
    state = state.copyWith(phoneBusy: true, clearError: true);
    try {
      final verified = await _repository.verifyPhoneOtp(
        phone: phone,
        otp: otp,
        colorMode: colorMode,
      );
      if (!ref.mounted) return null;
      final freeEligible = verified['freeEligible'] == true;
      final society = verified['society'] == true;
      final remainingRaw = verified['remaining'];
      final remaining = remainingRaw is num ? remainingRaw.toInt() : null;
      final notice = verified['message']?.toString();
      final token = verified['phoneProofToken']?.toString();
      state = state.copyWith(
        phoneBusy: false,
        clearError: true,
        clearPhoneNotice: true,
        pendingPhoneProofToken:
            freeEligible && token != null && token.isNotEmpty ? token : null,
        clearPendingPhoneProofToken:
            !(freeEligible && token != null && token.isNotEmpty),
      );
      return DigilockerQuotaSummary(
        freeEligible: freeEligible,
        society: society,
        colorMode: colorMode,
        remaining: remaining,
        message: notice,
        phoneProofToken:
            freeEligible && token != null && token.isNotEmpty ? token : null,
      );
    } catch (error) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        phoneBusy: false,
        error: userFacingError(error),
      );
      return null;
    }
  }

  Future<void> continueAfterQuotaSummary(DigilockerQuotaSummary summary) async {
    final token = summary.phoneProofToken ?? state.pendingPhoneProofToken;
    if (summary.freeEligible && token != null && token.isNotEmpty) {
      state = state.copyWith(
        clearPhoneNotice: true,
        clearError: true,
        clearPendingPhoneProofToken: true,
      );
      await _runPreparePrint(phoneProofToken: token);
      return;
    }
    state = state.copyWith(
      phoneNotice: summary.message ??
          'Free print is not available for this number. Continue with payment.',
      clearError: true,
      clearPendingPhoneProofToken: true,
    );
    await _runPreparePrint();
  }

  Future<void> _runPreparePrint({String? phoneProofToken}) async {
    final sessionId = state.sessionId;
    final documentId = state.pendingDocumentId;
    final colorMode = state.colorMode;
    if (sessionId == null || documentId == null || colorMode == null) {
      return;
    }
    final documents = state.documents;
    final documentTitle = state.pendingDocumentTitle;
    final notice = state.phoneNotice;
    final bw = state.bwChargeRupees;
    final color = state.colorChargeRupees;

    state = state.copyWith(
      phase: DigilockerPhase.preparingPreview,
      clearError: true,
      clearMessage: true,
    );

    try {
      final job = await _repository.printDocument(
        sessionId: sessionId,
        documentId: documentId,
        title: documentTitle,
        colorMode: colorMode,
        phoneProofToken: phoneProofToken,
      );
      final jobId = job['id'] as String;
      final title = job['title'] as String? ?? documentTitle ?? 'document';
      final pagesExpected = (job['pagesExpected'] as num?)?.toInt() ??
          (job['pageCount'] as num?)?.toInt() ??
          1;
      final paymentRequired = job['paymentRequired'] == true;
      final amountPaise = (job['amountPaise'] as num?)?.toInt() ?? 0;
      final qrImageUrl = job['qrImageUrl'] as String?;
      final jobColorMode = job['printColorMode'] as String? ?? colorMode;
      final bytes = await _repository.downloadPrintContent(jobId);

      final dir = Directory(p.join(Directory.systemTemp.path, 'skp_digilocker'));
      await dir.create(recursive: true);
      final filePath = p.join(dir.path, '$jobId.pdf');
      await File(filePath).writeAsBytes(bytes, flush: true);

      if (!ref.mounted) return;
      state = DigilockerUiState(
        phase: paymentRequired
            ? DigilockerPhase.awaitingPayment
            : DigilockerPhase.previewing,
        sessionId: sessionId,
        documents: documents,
        pendingDocumentId: documentId,
        pendingDocumentTitle: documentTitle,
        colorMode: colorMode,
        bwChargeRupees: bw,
        colorChargeRupees: color,
        previewTitle: title,
        previewBytes: bytes,
        previewFilePath: filePath,
        previewJobId: jobId,
        pagesExpected: pagesExpected,
        printColorMode: jobColorMode,
        paymentRequired: paymentRequired,
        amountPaise: amountPaise,
        qrImageUrl: qrImageUrl,
        phoneNotice: paymentRequired ? notice : null,
      );
      if (paymentRequired) {
        _startPaymentPoll();
      }
    } catch (error) {
      if (!ref.mounted) return;
      state = DigilockerUiState(
        phase: DigilockerPhase.printResult,
        sessionId: sessionId,
        documents: documents,
        pendingDocumentId: documentId,
        pendingDocumentTitle: documentTitle,
        colorMode: colorMode,
        bwChargeRupees: bw,
        colorChargeRupees: color,
        printConfirmed: false,
        error: userFacingError(error),
        message: userFacingError(error),
        paperOut: error is ApiException && error.code == 'printing_paused',
      );
    }
  }

  void _startPaymentPoll() {
    _stopPaymentPoll();
    _paymentPoll = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollPaymentOnce());
    });
  }

  Future<void> _pollPaymentOnce() async {
    final jobId = state.previewJobId;
    if (jobId == null || state.phase != DigilockerPhase.awaitingPayment) {
      return;
    }
    try {
      final body = await _repository.getPrintJobPayment(jobId);
      if (!ref.mounted) return;
      final status = body['status'] as String? ?? '';
      if (status == 'PAID') {
        _stopPaymentPoll();
        state = state.copyWith(
          phase: DigilockerPhase.previewing,
          clearError: true,
          clearMessage: true,
        );
        return;
      }
      if (status == 'EXPIRED' || status == 'CANCELLED') {
        _stopPaymentPoll();
        state = state.copyWith(
          phase: DigilockerPhase.printResult,
          printConfirmed: false,
          error: 'Payment window expired. Try again.',
          message: 'Payment window expired. Try again.',
        );
      }
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(error: userFacingError(error));
    }
  }

  Future<void> backFromPrintFlow() async {
    final phase = state.phase;
    if (phase == DigilockerPhase.enteringPhone) {
      state = state.copyWith(
        phase: DigilockerPhase.choosingPrintOptions,
        otpSent: false,
        otpDigits: '',
        phoneBusy: false,
        clearError: true,
        clearPhoneNotice: true,
      );
      return;
    }
    if (phase == DigilockerPhase.choosingPrintOptions ||
        phase == DigilockerPhase.awaitingPayment) {
      _stopPaymentPoll();
      backToDocuments();
      return;
    }
    backToDocuments();
  }

  Future<void> confirmPrint() async {
    final sessionId = state.sessionId;
    final documents = state.documents;
    final bytes = state.previewBytes;
    final jobId = state.previewJobId;
    final title = state.previewTitle ?? 'document';
    final filePath = state.previewFilePath;
    if (sessionId == null ||
        bytes == null ||
        jobId == null ||
        state.phase != DigilockerPhase.previewing) {
      return;
    }
    final failures = state.printFailures;
    final pagesExpected = state.pagesExpected;
    final colorMode = state.printColorMode;

    state = state.copyWith(
      phase: DigilockerPhase.printing,
      clearError: true,
      clearMessage: true,
    );

    try {
      final outcome = await _coordinator.printAndReconcile(
        jobId: jobId,
        title: title,
        pdfBytes: bytes,
        pagesExpected: pagesExpected,
        colorMode: colorMode,
        holdForRetry: failures == 0,
        reportStatus: _repository.reportStatus,
        onProgress: (message) {
          if (state.message == message) return;
          state = state.copyWith(
            phase: DigilockerPhase.printing,
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
          pagesExpected: pagesExpected,
          printColorMode: colorMode,
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
          pagesExpected: pagesExpected,
          printColorMode: colorMode,
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
        pagesExpected: pagesExpected,
        printColorMode: colorMode,
        printFailures: failures + 1,
        error: userFacingError(error),
      );
    }
  }

  Future<void> abandonRetry() async {
    if (state.printFailures != 1 || state.paperOut) return;
    final jobId = state.previewJobId;
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
    final jobId = state.previewJobId;
    if (jobId == null || jobId.isEmpty) return;
    await PrintJobSupport(ref.read(apiClientProvider)).send(
      jobId: jobId,
      message: state.error ?? 'Print failed',
    );
    state = state.copyWith(
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
    _stopPaymentPoll();
    final sessionId = state.sessionId;
    if (sessionId == null) {
      return;
    }
    unawaited(_deletePreviewFile(state.previewFilePath));
    state = DigilockerUiState(
      phase: DigilockerPhase.ready,
      sessionId: sessionId,
      documents: state.documents,
      message: 'Choose any document to print.',
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
