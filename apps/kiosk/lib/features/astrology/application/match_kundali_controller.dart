import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_paid_print.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_insights.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_result.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

class MatchKundaliUiState {
  const MatchKundaliUiState({
    this.phase = MatchKundaliPhase.groom,
    this.result,
    this.error,
    this.groom,
    this.bride,
    this.print = const ReportPrintSnapshot(),
  });

  final MatchKundaliPhase phase;
  final MatchKundaliResult? result;
  final String? error;
  final MatchPersonInput? groom;
  final MatchPersonInput? bride;
  final ReportPrintSnapshot print;

  MatchKundaliUiState copyWith({
    MatchKundaliPhase? phase,
    MatchKundaliResult? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
    MatchPersonInput? groom,
    MatchPersonInput? bride,
    ReportPrintSnapshot? print,
  }) {
    return MatchKundaliUiState(
      phase: phase ?? this.phase,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      groom: groom ?? this.groom,
      bride: bride ?? this.bride,
      print: print ?? this.print,
    );
  }
}

class MatchKundaliController extends Notifier<MatchKundaliUiState> {
  AstrologyInsightLocale _printLocale = AstrologyInsightLocale.en;
  late AstrologyPaidPrint _paid;

  @override
  MatchKundaliUiState build() {
    _paid = AstrologyPaidPrint(
      mounted: () => ref.mounted,
      readPrint: () => state.print,
      applyPrint: (print) {
        state = state.copyWith(
          print: print,
          error: print.error,
          clearError: print.error == null,
        );
      },
      loadChargeRupees: () async {
        final options = await _repository.kundaliPrintOptions();
        return (options['chargeRupees'] as num?)?.toInt() ?? 0;
      },
      sendOtp: (phone) async {
        await _repository.requestKundaliPhoneOtp(phone);
      },
      checkOtp: _repository.verifyKundaliPhoneOtp,
      prepareJob: _preparePaidJob,
      pollPayment: (current) => _printSupport.pollPayment(current),
      productLabel: 'Match Kundali',
    );
    ref.onDispose(_paid.dispose);
    return const MatchKundaliUiState();
  }

  AstrologyRepository get _repository => ref.read(astrologyRepositoryProvider);

  ReportPrintSupport get _printSupport => ReportPrintSupport(
        api: ref.read(apiClientProvider),
        coordinator: ref.read(printCoordinatorProvider),
        tempFolderName: 'skp_astrology',
      );

  void showBride() {
    state = state.copyWith(phase: MatchKundaliPhase.bride, clearError: true);
  }

  void showGroom() {
    state = state.copyWith(phase: MatchKundaliPhase.groom, clearError: true);
  }

  void setError(String message) {
    state = state.copyWith(error: message);
  }

  void reset() {
    _paid.stopPoll();
    _paid.clearPendingToken();
    state = const MatchKundaliUiState();
  }

  Future<void> submit({
    required MatchPersonInput groom,
    required MatchPersonInput bride,
  }) async {
    state = state.copyWith(
      phase: MatchKundaliPhase.loading,
      clearError: true,
      clearResult: true,
      groom: groom,
      bride: bride,
      print: const ReportPrintSnapshot(),
    );
    try {
      final result = await _repository.createMatch(groom: groom, bride: bride);
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: MatchKundaliPhase.result,
        result: result,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: MatchKundaliPhase.bride,
        error: userFacingError(error),
      );
    }
  }

  Map<String, dynamic> _personJson(MatchPersonInput person, {String gender = 'other'}) {
    return {
      'name': person.name,
      'gender': gender,
      'dateOfBirth': person.dateOfBirth,
      'birthTime': person.birthTime,
      'birthPlace': person.birthPlace,
      'birthTimeUnknown': person.birthTimeUnknown,
    };
  }

  Future<void> preparePrint({
    AstrologyInsightLocale locale = AstrologyInsightLocale.en,
  }) async {
    final result = state.result;
    final groom = state.groom;
    final bride = state.bride;
    _printLocale = locale;
    if (result == null ||
        groom == null ||
        bride == null ||
        state.phase != MatchKundaliPhase.result) {
      return;
    }
    await _paid.begin();
  }

  Future<void> choosePhoneQuota() => _paid.choosePhone();

  Future<void> choosePayDirect() => _paid.choosePay();

  void setPrintPhoneDigits(String value) => _paid.setPhoneDigits(value);

  void setPrintOtpDigits(String value) => _paid.setOtpDigits(value);

  Future<void> requestPrintPhoneOtp() => _paid.requestOtp();

  Future<AstrologyPrintQuota?> verifyPrintPhoneOtp() => _paid.verifyOtp();

  Future<void> continueAfterQuotaSummary(AstrologyPrintQuota summary) =>
      _paid.continueAfterQuota(summary);

  Future<void> backFromPrintFlow() => _paid.back(cancel: cancelPrintPreview);

  Future<ReportPrintSnapshot> _preparePaidJob(String? phoneProofToken) async {
    final result = state.result;
    final groom = state.groom;
    final bride = state.bride;
    if (result == null || groom == null || bride == null) {
      return state.print.copyWith(
        phase: ReportPrintPhase.printResult,
        printConfirmed: false,
        error: 'No reading to print',
        message: 'No reading to print',
      );
    }
    final printLocale = _printLocale;
    final bullets = result.insights.forLocale(printLocale);
    return _printSupport.prepare(
      createJobPath: '/astrology/match/print',
      body: {
        'groom': _personJson(groom, gender: 'male'),
        'bride': _personJson(bride, gender: 'female'),
        'score': {
          'total': result.score.total,
          'max': result.score.max,
          'summary': result.score.summary,
          'tone': result.score.tone,
        },
        'kutas': [
          for (final kuta in padMatchKutas(result.kutas))
            {
              'key': kuta.key,
              'name': kuta.name,
              'maxPoints': kuta.maxPoints,
              if (kuta.points != null) 'points': kuta.points,
              'nature': kuta.nature,
              'verdict': kuta.verdict,
            },
        ],
        if (result.accuracyNote != null) 'accuracyNote': result.accuracyNote,
        'disclaimer': result.disclaimer,
        'locale': printLocale.apiValue,
        if (bullets.isNotEmpty) 'insightBullets': bullets,
        'phoneProofToken': ?phoneProofToken,
      },
      previous: state.print,
    );
  }

  Future<void> confirmPrint() async {
    if (state.print.phase != ReportPrintPhase.previewing) return;
    state = state.copyWith(
      print: state.print.copyWith(phase: ReportPrintPhase.printing),
    );
    final next = await _printSupport.confirm(
      current: state.print,
      onProgress: (message) {
        if (!ref.mounted) return;
        if (state.print.message == message) return;
        state = state.copyWith(
          print: state.print.copyWith(
            phase: ReportPrintPhase.printing,
            message: message,
          ),
        );
      },
    );
    if (!ref.mounted) return;
    state = state.copyWith(print: next, error: next.error, clearError: next.error == null);
  }

  Future<void> cancelPrintPreview() async {
    _paid.stopPoll();
    _paid.clearPendingToken();
    await _printSupport.abandonRetry(state.print);
    if (!ref.mounted) return;
    state = state.copyWith(print: const ReportPrintSnapshot());
  }

  Future<void> tellStaffPrint() async {
    final next = await _printSupport.tellStaff(state.print, ref.read(apiClientProvider));
    if (!ref.mounted) return;
    state = state.copyWith(print: next);
  }

  Future<void> reportPrintPagesMissing() async {
    await _printSupport.reportPagesMissing(state.print, ref.read(apiClientProvider));
  }

  void clearPrintResult() {
    _paid.stopPoll();
    _paid.clearPendingToken();
    state = state.copyWith(print: const ReportPrintSnapshot());
  }
}

final matchKundaliControllerProvider =
    NotifierProvider.autoDispose<MatchKundaliController, MatchKundaliUiState>(
      MatchKundaliController.new,
    );
