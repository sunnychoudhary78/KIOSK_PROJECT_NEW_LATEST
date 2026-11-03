import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_print_mixin.dart';
import 'package:skp_kiosk/features/astrology/application/palm_quality_checker.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

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
    this.subject,
    this.print = const ReportPrintSnapshot(),
  });

  final AstrologyPhase phase;
  final PalmQualityResult? quality;
  final Uint8List? palmBytes;
  final AstrologyReading? reading;
  final String? error;
  final AstrologyBirthSubject? subject;
  final ReportPrintSnapshot print;

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
    AstrologyBirthSubject? subject,
    ReportPrintSnapshot? print,
  }) {
    return AstrologyUiState(
      phase: phase ?? this.phase,
      quality: clearQuality ? null : (quality ?? this.quality),
      palmBytes: clearPalmBytes ? null : (palmBytes ?? this.palmBytes),
      reading: clearReading ? null : (reading ?? this.reading),
      error: clearError ? null : (error ?? this.error),
      subject: subject ?? this.subject,
      print: print ?? this.print,
    );
  }
}

class AstrologyController extends Notifier<AstrologyUiState> {
  static const autoCaptureHold = Duration(milliseconds: 1100);
  static const _stillsToCapture = 4;
  final PalmQualityChecker _checker = const PalmQualityChecker();
  DateTime? _goodSince;
  int _goodStreak = 0;

  @override
  AstrologyUiState build() => const AstrologyUiState();

  AstrologyRepository get _repository => ref.read(astrologyRepositoryProvider);

  ReportPrintSupport get _printSupport => ReportPrintSupport(
        api: ref.read(apiClientProvider),
        coordinator: ref.read(printCoordinatorProvider),
        tempFolderName: 'skp_astrology',
      );

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
    double? latitude,
    double? longitude,
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

    final subject = AstrologyBirthSubject(
      name: trimmedName,
      gender: gender,
      dateOfBirth: dateOfBirth,
      birthTime: birthTimeUnknown ? '12:00' : birthTime,
      birthPlace: trimmedPlace,
      birthTimeUnknown: birthTimeUnknown,
    );

    state = state.copyWith(
      phase: AstrologyPhase.submitting,
      clearError: true,
      clearReading: true,
      subject: subject,
      print: const ReportPrintSnapshot(),
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
          latitude: latitude,
          longitude: longitude,
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

  Future<void> preparePrint() async {
    final reading = state.reading;
    final subject = state.subject;
    if (reading == null ||
        subject == null ||
        state.phase != AstrologyPhase.result) {
      return;
    }

    state = state.copyWith(
      clearError: true,
      print: state.print.copyWith(
        phase: ReportPrintPhase.preparingPreview,
        clearError: true,
        clearMessage: true,
      ),
    );

    final palmBytes = state.palmBytes;
    final next = await _printSupport.prepare(
      createJobPath: '/astrology/readings/print',
      body: {
        'subject': subject.toJson(),
        'chart': {
          if (reading.chart.lagna != null) 'lagna': reading.chart.lagna,
          if (reading.chart.sunSign != null) 'sunSign': reading.chart.sunSign,
          if (reading.chart.moonSign != null) 'moonSign': reading.chart.moonSign,
          if (reading.chart.nakshatra != null)
            'nakshatra': reading.chart.nakshatra,
          if (reading.chart.currentDasha != null)
            'currentDasha': reading.chart.currentDasha,
        },
        'palm': {
          'summary': reading.palm.summary,
          'lifeLine': reading.palm.lifeLine,
          'heartLine': reading.palm.heartLine,
          'headLine': reading.palm.headLine,
          'fateLine': reading.palm.fateLine,
        },
        'reading': {
          'overview': reading.sections.overview,
          'personality': reading.sections.personality,
          'career': reading.sections.career,
          'health': reading.sections.health,
          'relationships': reading.sections.relationships,
          'period': reading.sections.period,
        },
        if (palmBytes != null) 'palmJpegBase64': base64Encode(palmBytes),
        'disclaimer': reading.disclaimer,
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

final astrologyControllerProvider =
    NotifierProvider.autoDispose<AstrologyController, AstrologyUiState>(
  AstrologyController.new,
);
