import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_result.dart';

class MatchKundaliUiState {
  const MatchKundaliUiState({
    this.phase = MatchKundaliPhase.groom,
    this.result,
    this.error,
  });

  final MatchKundaliPhase phase;
  final MatchKundaliResult? result;
  final String? error;

  MatchKundaliUiState copyWith({
    MatchKundaliPhase? phase,
    MatchKundaliResult? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
  }) {
    return MatchKundaliUiState(
      phase: phase ?? this.phase,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MatchKundaliController extends Notifier<MatchKundaliUiState> {
  @override
  MatchKundaliUiState build() => const MatchKundaliUiState();

  AstrologyRepository get _repository => ref.read(astrologyRepositoryProvider);

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
}

final matchKundaliControllerProvider =
    NotifierProvider.autoDispose<MatchKundaliController, MatchKundaliUiState>(
      MatchKundaliController.new,
    );
