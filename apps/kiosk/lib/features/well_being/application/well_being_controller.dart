import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_device.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_provider.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/features/well_being/application/vitals_line_parser.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_state.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_mode.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_phase.dart';

final wellBeingControllerProvider =
    NotifierProvider.autoDispose<WellBeingController, WellBeingUiState>(
  WellBeingController.new,
);

class WellBeingController extends Notifier<WellBeingUiState> {
  final VitalsLineParser _parser = VitalsLineParser();
  StreamSubscription<String>? _incomingSub;
  ProviderSubscription<SerialUiState>? _serialWatch;

  static const _cmdStop = '{"command":"stop"}';
  static const _cmdStartMax =
      '{"command":"start","sensor":"max30102"}';
  static const _cmdStartTemp =
      '{"command":"start","sensor":"mlx90614"}';

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
      phase: WellBeingPhase.choose,
      activeMode: WellBeingMode.none,
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

    await _ensureConnected();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    await _bindIncoming();
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    if (ref.mounted && state.isConnected) {
      state = state.copyWith(
        phase: WellBeingPhase.choose,
        statusMessage: 'Choose a measurement',
      );
    }
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

  Future<void> startOxygen() async {
    if (!ref.mounted || !state.sessionActive || !state.isConnected) {
      return;
    }
    state = state.copyWith(
      activeMode: WellBeingMode.oxi,
      phase: WellBeingPhase.oxiIdle,
      fingerDetected: false,
      collectionTotalSeconds: VitalsLineParser.maxCollectionSeconds,
      secondsRemaining: VitalsLineParser.maxCollectionSeconds,
      measurePct: 0,
      clearLiveHeartRate: true,
      clearLiveSpO2: true,
      clearFinalHeartRate: true,
      clearFinalSpO2: true,
      clearLiveTempC: true,
      clearLiveTempF: true,
      clearFinalTempC: true,
      clearFinalTempF: true,
      clearError: true,
      statusMessage: 'Place your finger gently on the sensor',
    );
    await _sendCommand(_cmdStartMax);
  }

  Future<void> startTemperature() async {
    if (!ref.mounted || !state.sessionActive || !state.isConnected) {
      return;
    }
    state = state.copyWith(
      activeMode: WellBeingMode.temp,
      phase: WellBeingPhase.tempMeasuring,
      fingerDetected: false,
      collectionTotalSeconds: VitalsLineParser.tempCollectionSeconds,
      secondsRemaining: VitalsLineParser.tempCollectionSeconds,
      measurePct: 0,
      clearLiveHeartRate: true,
      clearLiveSpO2: true,
      clearFinalHeartRate: true,
      clearFinalSpO2: true,
      clearLiveTempC: true,
      clearLiveTempF: true,
      clearFinalTempC: true,
      clearFinalTempF: true,
      clearError: true,
      statusMessage: 'Hold steady near the temperature sensor',
    );
    await _sendCommand(_cmdStartTemp);
  }

  Future<void> returnToHub() async {
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    await _sendCommand(_cmdStop, silent: true);
    if (!ref.mounted || !state.sessionActive) {
      return;
    }
    state = state.copyWith(
      phase: WellBeingPhase.choose,
      activeMode: WellBeingMode.none,
      fingerDetected: false,
      collectionTotalSeconds: VitalsLineParser.maxCollectionSeconds,
      secondsRemaining: VitalsLineParser.maxCollectionSeconds,
      measurePct: 0,
      clearLiveHeartRate: true,
      clearLiveSpO2: true,
      clearFinalHeartRate: true,
      clearFinalSpO2: true,
      clearLiveTempC: true,
      clearLiveTempF: true,
      clearFinalTempC: true,
      clearFinalTempF: true,
      statusMessage: state.isConnected
          ? 'Choose a measurement'
          : state.statusMessage,
    );
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
        statusMessage: 'Choose a measurement',
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
    if (serial.isConnected && state.phase == WellBeingPhase.choose) {
      statusMessage = 'Choose a measurement';
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

    if (sample.isReady) {
      AppLogger.info(
        'Sensor ready: max30102=${sample.max30102Ok} mlx90614=${sample.mlx90614Ok}',
      );
      return;
    }

    if (sample.isError) {
      state = state.copyWith(
        lastError: sample.errorMessage,
        statusMessage: _humanError(sample.errorMessage),
      );
      return;
    }

    if (sample.isInfo) {
      return;
    }

    if (state.activeMode == WellBeingMode.oxi) {
      _applyOxiSample(sample);
      return;
    }

    if (state.activeMode == WellBeingMode.temp) {
      _applyTempSample(sample);
    }
  }

  void _applyOxiSample(VitalsParseResult sample) {
    if (state.phase == WellBeingPhase.oxiComplete) {
      return;
    }

    if (sample.isPlaceFinger) {
      state = state.copyWith(
        phase: WellBeingPhase.oxiIdle,
        fingerDetected: false,
        secondsRemaining: VitalsLineParser.maxCollectionSeconds,
        measurePct: 0,
        clearLiveHeartRate: true,
        clearLiveSpO2: true,
        statusMessage: 'Place your finger gently on the sensor',
      );
      return;
    }

    if (sample.isFingerDetected || sample.isSensorStarted) {
      state = state.copyWith(
        phase: WellBeingPhase.oxiMeasuring,
        fingerDetected: true,
        secondsRemaining: VitalsLineParser.maxCollectionSeconds,
        measurePct: 0,
        statusMessage: sample.isFingerDetected
            ? 'Finger detected — starting measurement'
            : 'Keep your finger still',
      );
      return;
    }

    if (sample.isMaxRecording ||
        (sample.isRecording && sample.sensor == null)) {
      final rem = sample.remSeconds?.ceil().clamp(
            0,
            VitalsLineParser.maxCollectionSeconds,
          );
      final total = VitalsLineParser.maxCollectionSeconds;
      final remaining = rem ?? state.secondsRemaining;
      final pct = ((total - remaining) / total * 100).clamp(0.0, 100.0);
      state = state.copyWith(
        phase: WellBeingPhase.oxiMeasuring,
        fingerDetected: true,
        secondsRemaining: remaining,
        measurePct: pct,
        statusMessage: 'Keep your finger still',
      );
      return;
    }

    if (sample.isFingerRemovedAbort) {
      state = state.copyWith(
        phase: WellBeingPhase.oxiIdle,
        fingerDetected: false,
        secondsRemaining: VitalsLineParser.maxCollectionSeconds,
        measurePct: 0,
        clearLiveHeartRate: true,
        clearLiveSpO2: true,
        statusMessage: 'Finger lost — place your finger again',
      );
      // Firmware aborted; user can place finger again after we re-start.
      unawaited(_sendCommand(_cmdStartMax, silent: true));
      return;
    }

    if (sample.isAborted) {
      state = state.copyWith(
        phase: WellBeingPhase.oxiCancelled,
        fingerDetected: false,
        lastError: sample.abortReason,
        statusMessage: _humanError(sample.abortReason),
      );
      return;
    }

    if (sample.isResult) {
      final finalHr = sample.finalHeartRate ?? sample.heartRate;
      final finalSpo2 = sample.finalSpO2 ?? sample.spo2;
      if (finalHr == null && finalSpo2 == null) {
        state = state.copyWith(
          phase: WellBeingPhase.oxiIdle,
          fingerDetected: false,
          statusMessage: 'No reading — place your finger again',
        );
        unawaited(_sendCommand(_cmdStartMax, silent: true));
        return;
      }
      state = state.copyWith(
        phase: WellBeingPhase.oxiComplete,
        fingerDetected: false,
        secondsRemaining: 0,
        measurePct: 100,
        finalHeartRate: finalHr,
        finalSpO2: finalSpo2,
        statusMessage: 'Measurement complete — you may remove your finger',
      );
      AppLogger.info('Oxi result: HR=$finalHr SpO2=$finalSpo2');
    }
  }

  void _applyTempSample(VitalsParseResult sample) {
    if (state.phase == WellBeingPhase.tempComplete) {
      return;
    }

    if (sample.isSensorStarted) {
      state = state.copyWith(
        phase: WellBeingPhase.tempMeasuring,
        secondsRemaining: VitalsLineParser.tempCollectionSeconds,
        measurePct: 0,
        statusMessage: 'Hold steady near the temperature sensor',
      );
      return;
    }

    if (sample.isTempRecording ||
        (sample.isRecording && sample.sensor == null)) {
      final rem = sample.remSeconds?.ceil().clamp(
            0,
            VitalsLineParser.tempCollectionSeconds,
          );
      final total = VitalsLineParser.tempCollectionSeconds;
      final remaining = rem ?? state.secondsRemaining;
      final pct = ((total - remaining) / total * 100).clamp(0.0, 100.0);
      state = state.copyWith(
        phase: WellBeingPhase.tempMeasuring,
        secondsRemaining: remaining,
        measurePct: pct,
        statusMessage: 'Measuring temperature — hold steady',
      );
      return;
    }

    if (sample.isAborted) {
      state = state.copyWith(
        lastError: sample.abortReason,
        statusMessage: _humanError(sample.abortReason),
        phase: WellBeingPhase.choose,
        activeMode: WellBeingMode.none,
      );
      return;
    }

    if (sample.isResult) {
      final tempC = sample.temperatureC;
      final tempF = sample.temperatureF;
      if (tempC == null) {
        state = state.copyWith(
          statusMessage: 'No temperature reading — try again',
          lastError: 'Temperature result missing',
        );
        return;
      }
      state = state.copyWith(
        phase: WellBeingPhase.tempComplete,
        secondsRemaining: 0,
        measurePct: 100,
        finalTempC: tempC,
        finalTempF: tempF,
        liveTempC: tempC,
        liveTempF: tempF,
        statusMessage: 'Temperature captured',
      );
      AppLogger.info('Temp result: ${tempC.toStringAsFixed(1)}°C');
    }
  }

  String _humanError(String? code) {
    return switch (code) {
      'finger_removed' => 'Finger removed during measurement',
      'user_stop' => 'Measurement stopped',
      'max30102_not_found' => 'Pulse oximeter sensor not found',
      'mlx90614_not_found' => 'Temperature sensor not found',
      'session_in_progress' => 'A measurement is already in progress',
      'no_sensor_requested' => 'No sensor requested',
      'unknown_sensor' || 'unknown_command' => 'Sensor command not understood',
      null || '' => 'Sensor error',
      _ => code,
    };
  }

  Future<void> _sendCommand(String command, {bool silent = false}) async {
    if (!ref.mounted) {
      return;
    }
    final serial = ref.read(serialControllerProvider);
    if (!serial.isConnected) {
      return;
    }
    try {
      await _serial.sendLine(command);
    } catch (error) {
      AppLogger.error('Well Being command failed: $command', error);
      if (!silent && ref.mounted) {
        state = state.copyWith(
          lastError: error.toString(),
          statusMessage: 'Could not talk to sensor',
        );
      }
    }
  }

  Future<void> _tearDown({required bool disconnect}) async {
    var shouldDisconnect = false;
    Future<void> Function()? doDisconnect;
    try {
      shouldDisconnect = disconnect && state.sessionActive;
      if (shouldDisconnect && ref.mounted) {
        final controller = ref.read(serialControllerProvider.notifier);
        try {
          if (ref.read(serialControllerProvider).isConnected) {
            await controller.sendLine(_cmdStop);
          }
        } catch (_) {}
        doDisconnect = controller.disconnect;
      }
    } catch (_) {
      try {
        if (disconnect) {
          final service = ref.read(serialServiceProvider);
          try {
            if (service.isConnected) {
              await service.sendLine(_cmdStop);
            }
          } catch (_) {}
          doDisconnect = () => service.disconnect(silent: true);
          shouldDisconnect = true;
        }
      } catch (_) {
        shouldDisconnect = false;
        doDisconnect = null;
      }
    }

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
