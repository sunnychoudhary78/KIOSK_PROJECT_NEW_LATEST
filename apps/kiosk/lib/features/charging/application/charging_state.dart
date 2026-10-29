import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/features/charging/domain/charging_phase.dart';

/// UI state for the Phone Charging flow.
class ChargingUiState {
  const ChargingUiState({
    this.phase = ChargingPhase.connecting,
    this.connectionStatus = SerialConnectionStatus.disconnected,
    this.portName,
    this.relayOn = false,
    this.statusMessage = 'Connecting…',
    this.lastError,
    this.sensorOk,
    this.sensorLost = false,
    this.volts,
    this.currentMa,
    this.powerW,
    this.stopReason,
    this.chargeStartedAt,
    this.capSecondsRemaining,
    this.hostStopRequested = false,
  });

  final ChargingPhase phase;
  final SerialConnectionStatus connectionStatus;
  final String? portName;
  final bool relayOn;
  final String statusMessage;
  final String? lastError;

  /// Last known INA226 health from the ready line or a charger snapshot.
  /// Null until the controller has reported it.
  final bool? sensorOk;

  /// Plug / full detection is not running. The socket still follows the host.
  final bool sensorLost;

  final double? volts;
  final double? currentMa;
  final double? powerW;
  final ChargingStopReason? stopReason;

  /// Wall clock when `plugged_in` (or a charging snapshot) was first seen.
  /// The on-screen 240-minute cap is counted from here. It does not turn
  /// the socket off.
  final DateTime? chargeStartedAt;

  /// Seconds left in the firmware safety cap. Null while not charging.
  final int? capSecondsRemaining;

  /// Host already asked for relay off. Snapshots must not reopen charging
  /// while `last_result` is still `plugged_in`.
  final bool hostStopRequested;

  bool get isConnected => connectionStatus == SerialConnectionStatus.connected;

  bool get socketArmed =>
      phase == ChargingPhase.waitingForPhone || phase == ChargingPhase.charging;

  ChargingUiState copyWith({
    ChargingPhase? phase,
    SerialConnectionStatus? connectionStatus,
    String? portName,
    bool clearPortName = false,
    bool? relayOn,
    String? statusMessage,
    String? lastError,
    bool clearError = false,
    bool? sensorOk,
    bool clearSensorOk = false,
    bool? sensorLost,
    double? volts,
    double? currentMa,
    double? powerW,
    bool clearReadings = false,
    ChargingStopReason? stopReason,
    bool clearStopReason = false,
    DateTime? chargeStartedAt,
    bool clearChargeStarted = false,
    int? capSecondsRemaining,
    bool clearCap = false,
    bool? hostStopRequested,
  }) {
    return ChargingUiState(
      phase: phase ?? this.phase,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      portName: clearPortName ? null : (portName ?? this.portName),
      relayOn: relayOn ?? this.relayOn,
      statusMessage: statusMessage ?? this.statusMessage,
      lastError: clearError ? null : (lastError ?? this.lastError),
      sensorOk: clearSensorOk ? null : (sensorOk ?? this.sensorOk),
      sensorLost: sensorLost ?? this.sensorLost,
      volts: clearReadings ? null : (volts ?? this.volts),
      currentMa: clearReadings ? null : (currentMa ?? this.currentMa),
      powerW: clearReadings ? null : (powerW ?? this.powerW),
      stopReason: clearStopReason ? null : (stopReason ?? this.stopReason),
      chargeStartedAt: clearChargeStarted
          ? null
          : (chargeStartedAt ?? this.chargeStartedAt),
      capSecondsRemaining: clearCap
          ? null
          : (capSecondsRemaining ?? this.capSecondsRemaining),
      hostStopRequested: hostStopRequested ?? this.hostStopRequested,
    );
  }

  factory ChargingUiState.initial() => const ChargingUiState();
}
