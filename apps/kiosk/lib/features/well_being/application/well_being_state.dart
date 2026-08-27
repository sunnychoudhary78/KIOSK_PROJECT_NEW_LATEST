import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_mode.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_phase.dart';

/// UI state for the dual-sensor Well Being measurement flow.
class WellBeingUiState {
  const WellBeingUiState({
    this.phase = WellBeingPhase.choose,
    this.activeMode = WellBeingMode.none,
    this.connectionStatus = SerialConnectionStatus.disconnected,
    this.portName,
    this.lastError,
    this.sessionActive = false,
    this.fingerDetected = false,
    this.collectionTotalSeconds = 20,
    this.secondsRemaining = 20,
    this.measurePct = 0,
    this.liveHeartRate,
    this.liveSpO2,
    this.finalHeartRate,
    this.finalSpO2,
    this.liveTempC,
    this.liveTempF,
    this.finalTempC,
    this.finalTempF,
    this.statusMessage,
  });

  final WellBeingPhase phase;
  final WellBeingMode activeMode;
  final SerialConnectionStatus connectionStatus;
  final String? portName;
  final String? lastError;
  final bool sessionActive;
  final bool fingerDetected;
  final int collectionTotalSeconds;
  final int secondsRemaining;
  final double measurePct;
  final double? liveHeartRate;
  final double? liveSpO2;
  final double? finalHeartRate;
  final double? finalSpO2;
  final double? liveTempC;
  final double? liveTempF;
  final double? finalTempC;
  final double? finalTempF;
  final String? statusMessage;

  bool get isConnected =>
      connectionStatus == SerialConnectionStatus.connected;

  String get connectionLabel => switch (connectionStatus) {
        SerialConnectionStatus.disconnected => 'No sensor',
        SerialConnectionStatus.connecting => 'Connecting…',
        SerialConnectionStatus.connected => 'Connected',
        SerialConnectionStatus.reconnecting => 'Reconnecting…',
        SerialConnectionStatus.error => 'Sensor error',
      };

  double get measureProgress {
    if (measurePct > 0) {
      return (measurePct / 100).clamp(0.0, 1.0);
    }
    final total = collectionTotalSeconds <= 0 ? 1 : collectionTotalSeconds;
    return ((total - secondsRemaining) / total).clamp(0.0, 1.0);
  }

  String get heartRateInterpretation {
    final bpm = finalHeartRate ?? liveHeartRate;
    if (bpm == null) {
      return '—';
    }
    if (bpm >= 60 && bpm <= 100) {
      return 'Normal Heart Rate';
    }
    return 'Attention Recommended';
  }

  String get spo2Interpretation {
    final value = finalSpO2 ?? liveSpO2;
    if (value == null) {
      return '—';
    }
    if (value >= 95) {
      return 'Excellent Oxygen Saturation';
    }
    return 'Low Oxygen Level';
  }

  String get temperatureInterpretation {
    final value = finalTempC ?? liveTempC;
    if (value == null) {
      return '—';
    }
    if (value >= 36.1 && value <= 37.2) {
      return 'Normal Range';
    }
    if (value > 37.2 && value <= 38.0) {
      return 'Slightly Elevated';
    }
    if (value > 38.0) {
      return 'Elevated — Seek Advice';
    }
    return 'Below Typical Range';
  }

  WellBeingUiState copyWith({
    WellBeingPhase? phase,
    WellBeingMode? activeMode,
    SerialConnectionStatus? connectionStatus,
    String? portName,
    bool clearPortName = false,
    String? lastError,
    bool clearError = false,
    bool? sessionActive,
    bool? fingerDetected,
    int? collectionTotalSeconds,
    int? secondsRemaining,
    double? measurePct,
    double? liveHeartRate,
    bool clearLiveHeartRate = false,
    double? liveSpO2,
    bool clearLiveSpO2 = false,
    double? finalHeartRate,
    bool clearFinalHeartRate = false,
    double? finalSpO2,
    bool clearFinalSpO2 = false,
    double? liveTempC,
    bool clearLiveTempC = false,
    double? liveTempF,
    bool clearLiveTempF = false,
    double? finalTempC,
    bool clearFinalTempC = false,
    double? finalTempF,
    bool clearFinalTempF = false,
    String? statusMessage,
    bool clearStatusMessage = false,
  }) {
    return WellBeingUiState(
      phase: phase ?? this.phase,
      activeMode: activeMode ?? this.activeMode,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      portName: clearPortName ? null : (portName ?? this.portName),
      lastError: clearError ? null : (lastError ?? this.lastError),
      sessionActive: sessionActive ?? this.sessionActive,
      fingerDetected: fingerDetected ?? this.fingerDetected,
      collectionTotalSeconds:
          collectionTotalSeconds ?? this.collectionTotalSeconds,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      measurePct: measurePct ?? this.measurePct,
      liveHeartRate:
          clearLiveHeartRate ? null : (liveHeartRate ?? this.liveHeartRate),
      liveSpO2: clearLiveSpO2 ? null : (liveSpO2 ?? this.liveSpO2),
      finalHeartRate:
          clearFinalHeartRate ? null : (finalHeartRate ?? this.finalHeartRate),
      finalSpO2: clearFinalSpO2 ? null : (finalSpO2 ?? this.finalSpO2),
      liveTempC: clearLiveTempC ? null : (liveTempC ?? this.liveTempC),
      liveTempF: clearLiveTempF ? null : (liveTempF ?? this.liveTempF),
      finalTempC: clearFinalTempC ? null : (finalTempC ?? this.finalTempC),
      finalTempF: clearFinalTempF ? null : (finalTempF ?? this.finalTempF),
      statusMessage:
          clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
    );
  }

  factory WellBeingUiState.initial() {
    return const WellBeingUiState(
      statusMessage: 'Connecting to sensor…',
    );
  }
}
