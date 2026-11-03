import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_print_mixin.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_insights.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_result.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

class TodayPeriodsUiState {
  const TodayPeriodsUiState({
    this.phase = TodayPeriodsPhase.form,
    this.result,
    this.error,
    this.subject,
    this.print = const ReportPrintSnapshot(),
  });

  final TodayPeriodsPhase phase;
  final TodayPeriodsResult? result;
  final String? error;
  final AstrologyBirthSubject? subject;
  final ReportPrintSnapshot print;

  TodayPeriodsUiState copyWith({
    TodayPeriodsPhase? phase,
    TodayPeriodsResult? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
    AstrologyBirthSubject? subject,
    ReportPrintSnapshot? print,
  }) {
    return TodayPeriodsUiState(
      phase: phase ?? this.phase,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      subject: subject ?? this.subject,
      print: print ?? this.print,
    );
  }
}

class TodayPeriodsController extends Notifier<TodayPeriodsUiState> {
  @override
  TodayPeriodsUiState build() => const TodayPeriodsUiState();

  AstrologyRepository get _repository => ref.read(astrologyRepositoryProvider);

  ReportPrintSupport get _printSupport => ReportPrintSupport(
        api: ref.read(apiClientProvider),
        coordinator: ref.read(printCoordinatorProvider),
        tempFolderName: 'skp_astrology',
      );

  void reset() {
    state = const TodayPeriodsUiState();
  }

  Future<void> submit({
    required String name,
    required String gender,
    required String dateOfBirth,
    required String birthTime,
    required String birthPlace,
    required bool birthTimeUnknown,
    double? latitude,
    double? longitude,
  }) async {
    final trimmedName = name.trim();
    final trimmedPlace = birthPlace.trim();
    if (trimmedName.isEmpty || trimmedPlace.length < 2) {
      state = state.copyWith(error: 'Name and birth place are required');
      return;
    }

    final subject = AstrologyBirthSubject(
      name: trimmedName,
      gender: gender,
      dateOfBirth: dateOfBirth,
      birthTime: birthTimeUnknown ? '12:00' : birthTime,
      birthPlace: trimmedPlace,
      birthTimeUnknown: birthTimeUnknown,
    );

    state = state.copyWith(
      phase: TodayPeriodsPhase.loading,
      clearError: true,
      clearResult: true,
      subject: subject,
      print: const ReportPrintSnapshot(),
    );

    try {
      final result = await _repository.createToday(
        TodaySubmitInput(
          name: trimmedName,
          gender: gender,
          dateOfBirth: dateOfBirth,
          birthTime: birthTimeUnknown ? '12:00' : birthTime,
          birthPlace: trimmedPlace,
          birthTimeUnknown: birthTimeUnknown,
          latitude: latitude,
          longitude: longitude,
        ),
      );
      if (!ref.mounted) return;
      if (result.dasha.label.trim().isEmpty) {
        state = state.copyWith(
          phase: TodayPeriodsPhase.form,
          error: 'Could not load today’s periods. Try again.',
        );
        return;
      }
      state = state.copyWith(
        phase: TodayPeriodsPhase.result,
        result: result,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: TodayPeriodsPhase.form,
        error: userFacingError(error),
      );
    }
  }

  Future<void> preparePrint({
    AstrologyInsightLocale locale = AstrologyInsightLocale.en,
  }) async {
    final result = state.result;
    final subject = state.subject;
    if (result == null ||
        subject == null ||
        state.phase != TodayPeriodsPhase.result) {
      return;
    }

    final bullets = result.insights.forLocale(locale);

    state = state.copyWith(
      print: state.print.copyWith(
        phase: ReportPrintPhase.preparingPreview,
        clearError: true,
        clearMessage: true,
      ),
    );

    final p = result.panchang;
    final next = await _printSupport.prepare(
      createJobPath: '/astrology/today/print',
      body: {
        'subject': subject.toJson(),
        'asOf': result.asOf?.toUtc().toIso8601String() ??
            DateTime.now().toUtc().toIso8601String(),
        'panchang': {
          if (p.weekday != null) 'weekday': p.weekday,
          if (p.tithi != null) 'tithi': p.tithi,
          if (p.nakshatra != null) 'nakshatra': p.nakshatra,
          if (p.yoga != null) 'yoga': p.yoga,
          if (p.karana != null) 'karana': p.karana,
          if (p.lunarMonth != null) 'lunarMonth': p.lunarMonth,
          if (p.sunrise != null) 'sunrise': p.sunrise,
          if (p.sunset != null) 'sunset': p.sunset,
          if (p.horaLord != null) 'horaLord': p.horaLord,
          if (p.dishaShool != null) 'dishaShool': p.dishaShool,
        },
        'dasha': {
          'label': result.dasha.label,
          'levels': result.dasha.levels,
        },
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

final todayPeriodsControllerProvider =
    NotifierProvider.autoDispose<TodayPeriodsController, TodayPeriodsUiState>(
      TodayPeriodsController.new,
    );
