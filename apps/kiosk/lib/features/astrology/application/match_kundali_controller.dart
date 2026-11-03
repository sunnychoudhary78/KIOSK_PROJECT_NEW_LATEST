import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
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
  @override
  MatchKundaliUiState build() => const MatchKundaliUiState();

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
    if (result == null ||
        groom == null ||
        bride == null ||
        state.phase != MatchKundaliPhase.result) {
      return;
    }

    final bullets = result.insights.forLocale(locale);

    state = state.copyWith(
      clearError: true,
      print: state.print.copyWith(
        phase: ReportPrintPhase.preparingPreview,
        clearError: true,
        clearMessage: true,
      ),
    );

    final next = await _printSupport.prepare(
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
        'locale': locale.apiValue,
        if (bullets.isNotEmpty) 'insightBullets': bullets,
      },
      previous: state.print,
    );
    if (!ref.mounted) return;
    state = state.copyWith(print: next, error: next.error, clearError: next.error == null);
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
    state = state.copyWith(print: const ReportPrintSnapshot());
  }
}

final matchKundaliControllerProvider =
    NotifierProvider.autoDispose<MatchKundaliController, MatchKundaliUiState>(
      MatchKundaliController.new,
    );
