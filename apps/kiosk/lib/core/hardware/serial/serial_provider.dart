import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_service.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';

const _maxIncomingChunks = 200;

final serialServiceProvider = Provider<SerialService>((ref) {
  final service = SerialService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

/// Live raw serial text stream (hardware layer only).
final serialIncomingProvider = StreamProvider<String>((ref) {
  final service = ref.watch(serialServiceProvider);
  return service.incoming;
});

final serialControllerProvider =
    NotifierProvider<SerialController, SerialUiState>(SerialController.new);

class SerialController extends Notifier<SerialUiState> {
  StreamSubscription<String>? _incomingSub;

  SerialService get _service => ref.read(serialServiceProvider);

  @override
  SerialUiState build() {
    ref.onDispose(() {
      unawaited(_incomingSub?.cancel());
      _incomingSub = null;
    });
    Future.microtask(refreshPorts);
    return const SerialUiState();
  }

  Future<void> refreshPorts() async {
    state = state.copyWith(scanning: true, clearError: true);
    try {
      final ports = _service.listPorts();
      final selected = state.selectedPortName;
      final stillPresent =
          selected != null && ports.any((p) => p.name == selected);
      state = state.copyWith(
        ports: ports,
        scanning: false,
        clearSelectedPort: selected != null && !stillPresent,
        selectedPortName: stillPresent ? selected : null,
      );
    } catch (error) {
      AppLogger.error('Serial port scan failed', error);
      state = state.copyWith(
        scanning: false,
        status: SerialConnectionStatus.error,
        lastError: error.toString(),
      );
    }
  }

  void selectPort(String? portName) {
    state = state.copyWith(
      selectedPortName: portName,
      clearSelectedPort: portName == null,
      clearError: true,
    );
  }

  Future<void> connect({int? baudRate}) async {
    if (state.status == SerialConnectionStatus.connecting ||
        state.status == SerialConnectionStatus.reconnecting) {
      return;
    }

    final portName = state.selectedPortName;
    if (portName == null || portName.isEmpty) {
      state = state.copyWith(
        status: SerialConnectionStatus.error,
        lastError: 'Select a serial port first',
      );
      return;
    }

    final baud = baudRate ?? state.baudRate;
    state = state.copyWith(
      status: SerialConnectionStatus.connecting,
      baudRate: baud,
      clearError: true,
    );

    try {
      await _service.connect(portName, baudRate: baud);
      await _bindIncoming();
      state = state.copyWith(
        status: SerialConnectionStatus.connected,
        selectedPortName: _service.connectedPortName ?? portName,
        clearError: true,
      );
    } catch (error) {
      AppLogger.error('Serial connect failed', error);
      state = state.copyWith(
        status: SerialConnectionStatus.error,
        lastError: error.toString(),
      );
    }
  }

  Future<void> disconnect() async {
    if (state.status == SerialConnectionStatus.connecting ||
        state.status == SerialConnectionStatus.reconnecting) {
      return;
    }

    await _incomingSub?.cancel();
    _incomingSub = null;
    try {
      await _service.disconnect();
      state = state.copyWith(
        status: SerialConnectionStatus.disconnected,
        clearError: true,
      );
    } catch (error) {
      AppLogger.error('Serial disconnect failed', error);
      state = state.copyWith(
        status: SerialConnectionStatus.error,
        lastError: error.toString(),
      );
    }
  }

  Future<void> reconnect() async {
    if (state.status == SerialConnectionStatus.connecting ||
        state.status == SerialConnectionStatus.reconnecting) {
      return;
    }

    final portName =
        state.selectedPortName ?? _service.connectedPortName;
    if (portName == null || portName.isEmpty) {
      state = state.copyWith(
        status: SerialConnectionStatus.error,
        lastError: 'Select a serial port first',
      );
      return;
    }

    state = state.copyWith(
      status: SerialConnectionStatus.reconnecting,
      selectedPortName: portName,
      clearError: true,
    );
    try {
      await _service.connect(portName, baudRate: state.baudRate);
      await _bindIncoming();
      state = state.copyWith(
        status: SerialConnectionStatus.connected,
        selectedPortName: _service.connectedPortName ?? portName,
        baudRate: _service.baudRate,
        clearError: true,
      );
    } catch (error) {
      AppLogger.error('Serial reconnect failed', error);
      state = state.copyWith(
        status: SerialConnectionStatus.error,
        lastError: error.toString(),
      );
    }
  }

  void clearIncoming() {
    state = state.copyWith(incomingLines: const []);
  }

  /// Send a newline-terminated command to the connected device.
  Future<void> sendLine(String line) async {
    if (!state.isConnected) {
      throw StateError('Serial port is not connected');
    }
    try {
      await _service.sendLine(line);
    } catch (error) {
      AppLogger.error('Serial send failed', error);
      state = state.copyWith(
        status: SerialConnectionStatus.error,
        lastError: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> _bindIncoming() async {
    await _incomingSub?.cancel();
    _incomingSub = _service.incoming.listen(
      _onRawChunk,
      onError: (Object error) {
        AppLogger.error('Serial incoming stream error', error);
        state = state.copyWith(
          status: SerialConnectionStatus.error,
          lastError: error.toString(),
        );
      },
    );
  }

  void _onRawChunk(String chunk) {
    // Preserve raw text; only split on newlines for scrollable debug display.
    final pieces = chunk.split(RegExp(r'\r?\n'));
    final next = List<String>.from(state.incomingLines);
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      final isLast = i == pieces.length - 1;
      if (piece.isEmpty && isLast) {
        continue;
      }
      if (piece.isEmpty) {
        continue;
      }
      next.add(piece);
    }
    while (next.length > _maxIncomingChunks) {
      next.removeAt(0);
    }
    state = state.copyWith(incomingLines: next);
  }
}
