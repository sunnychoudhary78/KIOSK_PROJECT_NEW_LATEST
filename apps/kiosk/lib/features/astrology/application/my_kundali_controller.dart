import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_result.dart';

class MyKundaliUiState {
  const MyKundaliUiState({
    this.phase = KundaliPhase.form,
    this.result,
    this.error,
  });

  final KundaliPhase phase;
  final KundaliResult? result;
  final String? error;

  MyKundaliUiState copyWith({
    KundaliPhase? phase,
    KundaliResult? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
  }) {
    return MyKundaliUiState(
      phase: phase ?? this.phase,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MyKundaliController extends Notifier<MyKundaliUiState> {
  @override
  MyKundaliUiState build() => const MyKundaliUiState();

  AstrologyRepository get _repository => ref.read(astrologyRepositoryProvider);

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

    state = state.copyWith(
      phase: KundaliPhase.loading,
      clearError: true,
      clearResult: true,
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
}

final myKundaliControllerProvider =
    NotifierProvider.autoDispose<MyKundaliController, MyKundaliUiState>(
  MyKundaliController.new,
);
