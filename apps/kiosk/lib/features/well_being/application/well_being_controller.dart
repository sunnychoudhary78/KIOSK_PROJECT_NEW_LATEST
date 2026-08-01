import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_device.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_provider.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/features/well_being/application/vitals_line_parser.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_state.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_phase.dart';

final wellBeingControllerProvider =
    NotifierProvider.autoDispose<WellBeingController, WellBeingUiState>(
  WellBeingController.new,
);

class WellBeingController extends Notifier<WellBeingUiState> {
  final VitalsLineParser _parser = VitalsLineParser();
  StreamSubscription<String>? _incomingSub;
  Timer? _measureTimer;
  Timer? _phaseDelayTimer;
  Timer? _flushTimer;
  ProviderSubscription<SerialUiState>? _serialWatch;

  @override
  WellBeingUiState build() {
    ref.onDispose(() {
      unawaited(_tearDown(disconnect: true));
    });
    return WellBeingUiState.initial();
  }

  SerialController get _serial => ref.read(serialControllerProvider.notifier);

  Future<void> startSession() async {
    if (!ref.mounted || state.sessionActive) {
      return;
    }

    state = state.copyWith(
      sessionActive: true,
      phase: WellBeingPhase.idle,
      clearError: true,
      statusMessage: 'Connecting to sensor…',
    );

    _serialWatch?.close();
    _serialWatch = ref.listen<SerialUiState>(serialControllerProvider, (
      previous,
      next,
    ) {
      if (!ref.mounted) {
        return;
      }
      _syncConnection(next);
    });
    _syncConnection(ref.read(serialControllerProvider));

    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!ref.mounted || !state.sessionActive) {
        return;
      }
      for (final result in _parser.flushTimedOut()) {
        _applySample(result);
      }
    });

    await _ensureConnected();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    await _bindIncoming();
  }

  Future<void> stopSession() async {
    await _tearDown(disconnect: true);
    if (ref.mounted) {
      state = WellBeingUiState.initial();
    }
  }

  Future<void> retryConnect() async {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(clearError: true);
    await _ensureConnected();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    await _bindIncoming();
  }

  Future<void> _ensureConnected() async {
    if (!ref.mounted) {
      return;
    }

    final serialState = ref.read(serialControllerProvider);
    if (serialState.isConnected) {
      final portName = serialState.selectedPortName ??
          (serialState.ports.isNotEmpty ? serialState.ports.first.name : null);
      state = state.copyWith(
        connectionStatus: SerialConnectionStatus.connected,
        portName: portName,
        statusMessage: 'Place your finger gently on the sensor',
      );
      return;
    }

    state = state.copyWith(
      connectionStatus: SerialConnectionStatus.connecting,
      statusMessage: 'Looking for sensor…',
    );

    await _serial.refreshPorts();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }

    final ports = ref.read(serialControllerProvider).ports;
    if (ports.isEmpty) {
      state = state.copyWith(
        connectionStatus: SerialConnectionStatus.error,
        lastError: 'No serial sensor found. Check the USB cable.',
        statusMessage: 'No sensor connected',
      );
      return;
    }

    final preferred = _preferPort(ports);
    _serial.selectPort(preferred);
    await _serial.connect();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }

    final after = ref.read(serialControllerProvider);
    _syncConnection(after);
    if (!after.isConnected) {
      state = state.copyWith(
        connectionStatus: SerialConnectionStatus.error,
        lastError: after.lastError ?? 'Could not open serial port',
        statusMessage: 'Unable to connect to sensor',
      );
    }
  }

  String _preferPort(List<SerialDevice> ports) {
    final selected = ref.read(serialControllerProvider).selectedPortName;
    if (selected != null && ports.any((p) => p.name == selected)) {
      return selected;
    }

    for (final port in ports) {
      final label = port.displayLabel.toLowerCase();
      if (label.contains('cp210') ||
          label.contains('silicon') ||
          label.contains('ch340') ||
          label.contains('usb')) {
        return port.name;
      }
    }
    return ports.first.name;
  }

  void _syncConnection(SerialUiState serial) {
    if (!ref.mounted || !state.sessionActive) {
      return;
    }

    String? statusMessage = state.statusMessage;
    if (serial.isConnected && state.phase == WellBeingPhase.idle) {
      statusMessage = 'Place your finger gently on the sensor';
    }
    if (serial.status == SerialConnectionStatus.error) {
      statusMessage = 'Sensor connection error';
    }
    if (serial.status == SerialConnectionStatus.disconnected) {
      statusMessage = 'No sensor connected';
    }

    state = state.copyWith(
      connectionStatus: serial.status,
      portName: serial.selectedPortName,
      lastError: serial.lastError,
      clearError: serial.lastError == null,
      statusMessage: statusMessage,
    );
  }

  Future<void> _bindIncoming() async {
    if (!ref.mounted) {
      return;
    }
    await _incomingSub?.cancel();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    _parser.reset();
    final service = ref.read(serialServiceProvider);
    _incomingSub = service.incoming.listen(
      _onChunk,
      onError: (Object error) {
        AppLogger.error('Well Being serial stream error', error);
        if (!ref.mounted) {
          return;
        }
        state = state.copyWith(
          connectionStatus: SerialConnectionStatus.error,
          lastError: error.toString(),
          statusMessage: 'Sensor read error',
        );
      },
    );
  }

  void _onChunk(String chunk) {
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    for (final result in _parser.addChunk(chunk)) {
      _applySample(result);
    }
  }

  void _applySample(VitalsParseResult sample) {
    if (!ref.mounted || !state.sessionActive || !sample.recognized) {
      return;
    }

    final finger = sample.finger ?? false;
    final validCount = sample.validCount ?? state.validCount;

    var liveHr = state.liveHeartRate;
    var liveSpo2 = state.liveSpO2;
    if (sample.validHr == true && sample.heartRate != null) {
      liveHr = sample.heartRate;
    }
    if (sample.validSpo2 == true && sample.spo2 != null) {
      liveSpo2 = sample.spo2;
    }

    state = state.copyWith(
      fingerDetected: finger,
      validCount: validCount,
      ir: sample.ir,
      signalLabel: sample.signalQualityLabel,
      liveHeartRate: liveHr,
      liveSpO2: liveSpo2,
    );

    switch (state.phase) {
      case WellBeingPhase.idle:
        if (finger) {
          _enterMeasuring();
        }
      case WellBeingPhase.measuring:
        if (!finger) {
          _enterCancelled();
        } else {
          state = state.copyWith(statusMessage: 'Keep your finger still');
        }
      case WellBeingPhase.cancelled:
        break;
      case WellBeingPhase.complete:
        if (!finger) {
          _scheduleReturnToIdle(const Duration(seconds: 2));
        }
    }

    AppLogger.info(
      'Vitals sample: finger=$finger HR=${sample.heartRate} '
      'SpO2=${sample.spo2} validCount=$validCount IR=${sample.ir}',
    );
  }

  void _enterMeasuring() {
    _phaseDelayTimer?.cancel();
    _measureTimer?.cancel();

    state = state.copyWith(
      phase: WellBeingPhase.measuring,
      secondsRemaining: WellBeingUiState.measureDurationSeconds,
      validCount: 0,
      clearLiveHeartRate: true,
      clearLiveSpO2: true,
      clearFinalHeartRate: true,
      clearFinalSpO2: true,
      statusMessage: 'Finger detected — measuring',
    );

    _measureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted || state.phase != WellBeingPhase.measuring) {
        timer.cancel();
        return;
      }
      final next = state.secondsRemaining - 1;
      if (next <= 0) {
        timer.cancel();
        _enterComplete();
        return;
      }
      state = state.copyWith(secondsRemaining: next);
    });
  }

  void _enterCancelled() {
    _measureTimer?.cancel();
    _measureTimer = null;
    _phaseDelayTimer?.cancel();

    state = state.copyWith(
      phase: WellBeingPhase.cancelled,
      statusMessage: 'Finger removed — measurement cancelled',
      validCount: 0,
    );

    _scheduleReturnToIdle(const Duration(seconds: 3));
  }

  void _enterComplete() {
    _measureTimer?.cancel();
    _measureTimer = null;
    _phaseDelayTimer?.cancel();

    final finalHr = state.liveHeartRate;
    final finalSpo2 = state.liveSpO2;

    state = state.copyWith(
      phase: WellBeingPhase.complete,
      secondsRemaining: 0,
      finalHeartRate: finalHr,
      finalSpO2: finalSpo2,
      statusMessage: 'Measurement complete',
    );
  }

  void _scheduleReturnToIdle(Duration delay) {
    _phaseDelayTimer?.cancel();
    _phaseDelayTimer = Timer(delay, () {
      if (!ref.mounted || !state.sessionActive) {
        return;
      }
      if (state.phase == WellBeingPhase.complete && state.fingerDetected) {
        // Stay on results until finger is removed.
        return;
      }
      _enterIdle();
    });
  }

  void _enterIdle() {
    _measureTimer?.cancel();
    _measureTimer = null;
    _phaseDelayTimer?.cancel();
    _phaseDelayTimer = null;

    state = state.copyWith(
      phase: WellBeingPhase.idle,
      secondsRemaining: WellBeingUiState.measureDurationSeconds,
      validCount: 0,
      clearLiveHeartRate: true,
      clearLiveSpO2: true,
      clearFinalHeartRate: true,
      clearFinalSpO2: true,
      statusMessage: state.isConnected
          ? 'Place your finger gently on the sensor'
          : state.statusMessage,
    );
  }

  Future<void> _tearDown({required bool disconnect}) async {
    var shouldDisconnect = false;
    Future<void> Function()? doDisconnect;
    try {
      shouldDisconnect = disconnect && state.sessionActive;
      if (shouldDisconnect && ref.mounted) {
        final controller = ref.read(serialControllerProvider.notifier);
        doDisconnect = controller.disconnect;
      }
    } catch (_) {
      try {
        if (disconnect) {
          final service = ref.read(serialServiceProvider);
          doDisconnect = () => service.disconnect(silent: true);
          shouldDisconnect = true;
        }
      } catch (_) {
        shouldDisconnect = false;
        doDisconnect = null;
      }
    }

    _measureTimer?.cancel();
    _measureTimer = null;
    _phaseDelayTimer?.cancel();
    _phaseDelayTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;

    try {
      _serialWatch?.close();
    } catch (_) {}
    _serialWatch = null;

    final sub = _incomingSub;
    _incomingSub = null;
    try {
      await sub?.cancel();
    } catch (_) {}

    _parser.reset();

    if (shouldDisconnect && doDisconnect != null) {
      try {
        await doDisconnect();
      } catch (error) {
        AppLogger.error('Well Being serial disconnect failed', error);
      }
    }
  }
}
