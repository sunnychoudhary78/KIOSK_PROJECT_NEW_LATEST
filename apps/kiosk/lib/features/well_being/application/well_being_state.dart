import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_phase.dart';

/// UI state for the firmware-matched Well Being measurement flow.
class WellBeingUiState {
  const WellBeingUiState({
    this.phase = WellBeingPhase.idle,
    this.connectionStatus = SerialConnectionStatus.disconnected,
    this.portName,
    this.lastError,
    this.sessionActive = false,
    this.fingerDetected = false,
    this.validCount = 0,
    this.secondsRemaining = measureDurationSeconds,
    this.liveHeartRate,
    this.liveSpO2,
    this.finalHeartRate,
    this.finalSpO2,
    this.ir,
    this.signalLabel = 'Unknown',
    this.statusMessage,
  });

  static const measureDurationSeconds = 45;

  final WellBeingPhase phase;
  final SerialConnectionStatus connectionStatus;
  final String? portName;
  final String? lastError;
  final bool sessionActive;
  final bool fingerDetected;
  final int validCount;
  final int secondsRemaining;
  final double? liveHeartRate;
  final double? liveSpO2;
  final double? finalHeartRate;
  final double? finalSpO2;
  final double? ir;
  final String signalLabel;
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
    final elapsed = measureDurationSeconds - secondsRemaining;
    if (elapsed <= 0) {
      return 0;
    }
    return (elapsed / measureDurationSeconds).clamp(0.0, 1.0);
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

  WellBeingUiState copyWith({
    WellBeingPhase? phase,
    SerialConnectionStatus? connectionStatus,
    String? portName,
    bool clearPortName = false,
    String? lastError,
    bool clearError = false,
    bool? sessionActive,
    bool? fingerDetected,
    int? validCount,
    int? secondsRemaining,
    double? liveHeartRate,
    bool clearLiveHeartRate = false,
    double? liveSpO2,
    bool clearLiveSpO2 = false,
    double? finalHeartRate,
    bool clearFinalHeartRate = false,
    double? finalSpO2,
    bool clearFinalSpO2 = false,
    double? ir,
    bool clearIr = false,
    String? signalLabel,
    String? statusMessage,
    bool clearStatusMessage = false,
  }) {
    return WellBeingUiState(
      phase: phase ?? this.phase,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      portName: clearPortName ? null : (portName ?? this.portName),
      lastError: clearError ? null : (lastError ?? this.lastError),
      sessionActive: sessionActive ?? this.sessionActive,
      fingerDetected: fingerDetected ?? this.fingerDetected,
      validCount: validCount ?? this.validCount,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      liveHeartRate:
          clearLiveHeartRate ? null : (liveHeartRate ?? this.liveHeartRate),
      liveSpO2: clearLiveSpO2 ? null : (liveSpO2 ?? this.liveSpO2),
      finalHeartRate:
          clearFinalHeartRate ? null : (finalHeartRate ?? this.finalHeartRate),
      finalSpO2: clearFinalSpO2 ? null : (finalSpO2 ?? this.finalSpO2),
      ir: clearIr ? null : (ir ?? this.ir),
      signalLabel: signalLabel ?? this.signalLabel,
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
