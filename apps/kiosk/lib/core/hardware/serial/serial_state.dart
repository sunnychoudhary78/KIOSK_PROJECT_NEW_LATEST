import 'package:skp_kiosk/core/hardware/serial/serial_device.dart';

enum SerialConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// UI-facing serial connection state (no protocol / temperature semantics).
class SerialUiState {
  const SerialUiState({
    this.ports = const [],
    this.selectedPortName,
    this.status = SerialConnectionStatus.disconnected,
    this.baudRate = 115200,
    this.lastError,
    this.incomingLines = const [],
    this.scanning = false,
  });

  final List<SerialDevice> ports;
  final String? selectedPortName;
  final SerialConnectionStatus status;
  final int baudRate;
  final String? lastError;

  /// Recent raw text chunks for the Serial Debug screen (newest last).
  final List<String> incomingLines;
  final bool scanning;

  bool get isConnected => status == SerialConnectionStatus.connected;

  String get statusLabel => switch (status) {
        SerialConnectionStatus.disconnected => 'Disconnected',
        SerialConnectionStatus.connecting => 'Connecting…',
        SerialConnectionStatus.connected => 'Connected',
        SerialConnectionStatus.reconnecting => 'Reconnecting…',
        SerialConnectionStatus.error => 'Error',
      };

  SerialUiState copyWith({
    List<SerialDevice>? ports,
    String? selectedPortName,
    bool clearSelectedPort = false,
    SerialConnectionStatus? status,
    int? baudRate,
    String? lastError,
    bool clearError = false,
    List<String>? incomingLines,
    bool? scanning,
  }) {
    return SerialUiState(
      ports: ports ?? this.ports,
      selectedPortName:
          clearSelectedPort ? null : (selectedPortName ?? this.selectedPortName),
      status: status ?? this.status,
      baudRate: baudRate ?? this.baudRate,
      lastError: clearError ? null : (lastError ?? this.lastError),
      incomingLines: incomingLines ?? this.incomingLines,
      scanning: scanning ?? this.scanning,
    );
  }
}
