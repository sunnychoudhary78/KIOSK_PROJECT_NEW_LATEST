import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/features/charging/domain/charging_phase.dart';

/// UI state for the Phone Charging flow.
class ChargingUiState {
  const ChargingUiState({
    this.phase = ChargingPhase.connecting,
    this.connectionStatus = SerialConnectionStatus.disconnected,
    this.portName,
    this.secondsRemaining = ChargingUiState.sessionSeconds,
    this.relayOn = false,
    this.statusMessage = 'Connecting…',
    this.lastError,
  });

  /// Power window after the ad completes.
  static const int sessionSeconds = 15 * 60;

  final ChargingPhase phase;
  final SerialConnectionStatus connectionStatus;
  final String? portName;
  final int secondsRemaining;
  final bool relayOn;
  final String statusMessage;
  final String? lastError;

  bool get isConnected =>
      connectionStatus == SerialConnectionStatus.connected;

  ChargingUiState copyWith({
    ChargingPhase? phase,
    SerialConnectionStatus? connectionStatus,
    String? portName,
    bool clearPortName = false,
    int? secondsRemaining,
    bool? relayOn,
    String? statusMessage,
    String? lastError,
    bool clearError = false,
  }) {
    return ChargingUiState(
      phase: phase ?? this.phase,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      portName: clearPortName ? null : (portName ?? this.portName),
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      relayOn: relayOn ?? this.relayOn,
      statusMessage: statusMessage ?? this.statusMessage,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  factory ChargingUiState.initial() => const ChargingUiState();
}
