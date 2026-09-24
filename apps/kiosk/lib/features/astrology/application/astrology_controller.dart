import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/astrology/application/palm_quality_checker.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';

final astrologyRepositoryProvider = Provider<AstrologyRepository>((ref) {
  return AstrologyRepository(ref.watch(apiClientProvider));
});

class AstrologyUiState {
  const AstrologyUiState({
    this.phase = AstrologyPhase.capture,
    this.quality,
    this.palmBytes,
    this.reading,
    this.error,
  });

  final AstrologyPhase phase;
  final PalmQualityResult? quality;
  final Uint8List? palmBytes;
  final AstrologyReading? reading;
  final String? error;

  bool get canCapture => quality?.ok == true;

  AstrologyUiState copyWith({
    AstrologyPhase? phase,
    PalmQualityResult? quality,
    bool clearQuality = false,
    Uint8List? palmBytes,
    bool clearPalmBytes = false,
    AstrologyReading? reading,
    bool clearReading = false,
    String? error,
    bool clearError = false,
  }) {
    return AstrologyUiState(
      phase: phase ?? this.phase,
      quality: clearQuality ? null : (quality ?? this.quality),
      palmBytes: clearPalmBytes ? null : (palmBytes ?? this.palmBytes),
      reading: clearReading ? null : (reading ?? this.reading),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AstrologyController extends Notifier<AstrologyUiState> {
  static const autoCaptureHold = Duration(milliseconds: 700);
  static const _stillsToCapture = 2;
  final PalmQualityChecker _checker = const PalmQualityChecker();
  DateTime? _goodSince;
  int _goodStreak = 0;

  @override
  AstrologyUiState build() => const AstrologyUiState();

  AstrologyRepository get _repository => ref.read(astrologyRepositoryProvider);

  PalmQualityResult evaluateFrame(Uint8List bytes, {DateTime? now}) {
    final quality = _checker.evaluate(bytes);
    if (state.phase != AstrologyPhase.capture || state.palmBytes != null) {
      return quality;
    }

    if (!quality.ok) {
      _goodSince = null;
      _goodStreak = 0;
      state = state.copyWith(quality: quality, clearError: true);
      return quality;
    }

    final clock = now ?? DateTime.now();
    _goodSince ??= clock;
    _goodStreak += 1;
    state = state.copyWith(quality: quality, clearError: true);

    if (_goodStreak >= _stillsToCapture &&
        clock.difference(_goodSince!) >= autoCaptureHold) {
      acceptPalm(bytes);
    }
    return quality;
  }

  void reportCameraStatus(String message) {
    if (state.phase != AstrologyPhase.capture || state.palmBytes != null) {
      return;
    }
    if (state.quality?.ok == true) {
      return;
    }
    state = state.copyWith(
      quality: PalmQualityResult(ok: false, message: message),
    );
  }

  void acceptPalm(Uint8List bytes, {bool strict = true}) {
    final quality = _checker.evaluate(bytes, strict: strict);
    if (!quality.ok) {
      _goodSince = null;
      _goodStreak = 0;
      state = state.copyWith(
        quality: quality,
        error: quality.message,
      );
      return;
    }
    _goodSince = null;
    _goodStreak = 0;
    state = state.copyWith(
      phase: AstrologyPhase.form,
      palmBytes: bytes,
      quality: quality,
      clearError: true,
    );
  }

  void retake() {
    _goodSince = null;
    _goodStreak = 0;
    state = const AstrologyUiState();
  }

  Future<void> submit({
    required String name,
    required String gender,
    required String dateOfBirth,
    required String birthTime,
    required String birthPlace,
    required bool birthTimeUnknown,
  }) async {
    final palm = state.palmBytes;
    if (palm == null) {
      state = state.copyWith(error: 'Capture a palm photo first');
      return;
    }
    final trimmedName = name.trim();
    final trimmedPlace = birthPlace.trim();
    if (trimmedName.isEmpty || trimmedPlace.length < 2) {
      state = state.copyWith(error: 'Name and birth place are required');
      return;
    }

    state = state.copyWith(
      phase: AstrologyPhase.submitting,
      clearError: true,
      clearReading: true,
    );

    try {
      final reading = await _repository.createReading(
        AstrologySubmitInput(
          name: trimmedName,
          gender: gender,
          dateOfBirth: dateOfBirth,
          birthTime: birthTimeUnknown ? '12:00' : birthTime,
          birthPlace: trimmedPlace,
          birthTimeUnknown: birthTimeUnknown,
          palmJpeg: palm,
        ),
      );
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        phase: AstrologyPhase.result,
        reading: reading,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        phase: AstrologyPhase.form,
        error: userFacingError(error),
      );
    }
  }
}

final astrologyControllerProvider =
    NotifierProvider.autoDispose<AstrologyController, AstrologyUiState>(
  AstrologyController.new,
);
