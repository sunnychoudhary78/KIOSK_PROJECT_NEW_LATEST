import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_result.dart';

class TodayPeriodsUiState {
  const TodayPeriodsUiState({
    this.phase = TodayPeriodsPhase.form,
    this.result,
    this.error,
  });

  final TodayPeriodsPhase phase;
  final TodayPeriodsResult? result;
  final String? error;

  TodayPeriodsUiState copyWith({
    TodayPeriodsPhase? phase,
    TodayPeriodsResult? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
  }) {
    return TodayPeriodsUiState(
      phase: phase ?? this.phase,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TodayPeriodsController extends Notifier<TodayPeriodsUiState> {
  @override
  TodayPeriodsUiState build() => const TodayPeriodsUiState();

  AstrologyRepository get _repository => ref.read(astrologyRepositoryProvider);

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
  }) async {
    final trimmedName = name.trim();
    final trimmedPlace = birthPlace.trim();
    if (trimmedName.isEmpty || trimmedPlace.length < 2) {
      state = state.copyWith(error: 'Name and birth place are required');
      return;
    }

    state = state.copyWith(
      phase: TodayPeriodsPhase.loading,
      clearError: true,
      clearResult: true,
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
}

final todayPeriodsControllerProvider =
    NotifierProvider.autoDispose<TodayPeriodsController, TodayPeriodsUiState>(
      TodayPeriodsController.new,
    );
