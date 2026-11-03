import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_print_mixin.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_insights.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_result.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

class MyKundaliUiState {
  const MyKundaliUiState({
    this.phase = KundaliPhase.form,
    this.result,
    this.error,
    this.subject,
    this.print = const ReportPrintSnapshot(),
  });

  final KundaliPhase phase;
  final KundaliResult? result;
  final String? error;
  final AstrologyBirthSubject? subject;
  final ReportPrintSnapshot print;

  MyKundaliUiState copyWith({
    KundaliPhase? phase,
    KundaliResult? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
    AstrologyBirthSubject? subject,
    bool clearSubject = false,
    ReportPrintSnapshot? print,
  }) {
    return MyKundaliUiState(
      phase: phase ?? this.phase,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      subject: clearSubject ? null : (subject ?? this.subject),
      print: print ?? this.print,
    );
  }
}

class MyKundaliController extends Notifier<MyKundaliUiState> {
  @override
  MyKundaliUiState build() => const MyKundaliUiState();

  AstrologyRepository get _repository => ref.read(astrologyRepositoryProvider);

  ReportPrintSupport get _printSupport => ReportPrintSupport(
        api: ref.read(apiClientProvider),
        coordinator: ref.read(printCoordinatorProvider),
        tempFolderName: 'skp_astrology',
      );

  void reset() {
    state = const MyKundaliUiState();
  }

  Future<void> submit({
    required String name,
    required String gender,
    required String dateOfBirth,
    required String birthTime,
    required String birthPlace,
    required bool birthTimeUnknown,
    required String style,
    double? latitude,
    double? longitude,
  }) async {
    final trimmedName = name.trim();
    final trimmedPlace = birthPlace.trim();
    if (trimmedName.isEmpty || trimmedPlace.length < 2) {
      state = state.copyWith(error: 'Name and birth place are required');
      return;
    }
    if (style != 'north' && style != 'south') {
      state = state.copyWith(error: 'Choose a chart style');
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
      phase: KundaliPhase.loading,
      clearError: true,
      clearResult: true,
      subject: subject,
      print: const ReportPrintSnapshot(),
    );

    try {
      final result = await _repository.createKundali(
        KundaliSubmitInput(
          name: trimmedName,
          gender: gender,
          dateOfBirth: dateOfBirth,
          birthTime: birthTimeUnknown ? '12:00' : birthTime,
          birthPlace: trimmedPlace,
          birthTimeUnknown: birthTimeUnknown,
          style: style,
          latitude: latitude,
          longitude: longitude,
        ),
      );
      if (!ref.mounted) {
        return;
      }
      if (result.svg.trim().isEmpty) {
        state = state.copyWith(
          phase: KundaliPhase.form,
          error: 'Could not draw the kundali. Try again.',
        );
        return;
      }
      state = state.copyWith(
        phase: KundaliPhase.result,
        result: result,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        phase: KundaliPhase.form,
        error: userFacingError(error),
      );
    }
  }

  Future<void> preparePrint({
    AstrologyInsightLocale locale = AstrologyInsightLocale.en,
  }) async {
    final result = state.result;
    final subject = state.subject;
    if (result == null || subject == null || state.phase != KundaliPhase.result) {
      return;
    }
    final charts = result.availableTabs
        .map(
          (entry) => {
            'key': entry.key,
            'title': entry.value.title,
            'subtitle': entry.value.subtitle,
            'svg': entry.value.svg,
          },
        )
        .toList();
    if (charts.isEmpty) {
      state = state.copyWith(error: 'No chart available to print');
      return;
    }

    final insightSections = <Map<String, dynamic>>[];
    for (final entry in result.availableTabs) {
      final bullets =
          result.insights.forChart(entry.key)?.forLocale(locale) ?? const [];
      if (bullets.isEmpty) continue;
      insightSections.add({
        'key': entry.key,
        'title': entry.value.title,
        'bullets': bullets,
      });
    }

    state = state.copyWith(
      clearError: true,
      print: state.print.copyWith(
        phase: ReportPrintPhase.preparingPreview,
        clearError: true,
        clearMessage: true,
      ),
    );

    final next = await _printSupport.prepare(
      createJobPath: '/astrology/kundali/print',
      body: {
        'subject': subject.toJson(),
        'style': result.style,
        'chart': {
          if (result.chart.lagna != null) 'lagna': result.chart.lagna,
          if (result.chart.sunSign != null) 'sunSign': result.chart.sunSign,
          if (result.chart.moonSign != null) 'moonSign': result.chart.moonSign,
          if (result.chart.nakshatra != null) 'nakshatra': result.chart.nakshatra,
          if (result.chart.currentDasha != null)
            'currentDasha': result.chart.currentDasha,
        },
        'charts': charts,
        'disclaimer': result.disclaimer,
        'locale': locale.apiValue,
        if (insightSections.isNotEmpty) 'insights': insightSections,
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

final myKundaliControllerProvider =
    NotifierProvider.autoDispose<MyKundaliController, MyKundaliUiState>(
  MyKundaliController.new,
);
