import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/hardware/serial/relay_command.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_device.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_provider.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/features/charging/application/charging_state.dart';
import 'package:skp_kiosk/features/charging/domain/charging_phase.dart';

final chargingControllerProvider =
    NotifierProvider.autoDispose<ChargingController, ChargingUiState>(
  ChargingController.new,
);

class ChargingController extends Notifier<ChargingUiState> {
  /// Firmware answers relay commands in the same loop; this covers USB delay.
  static const Duration relayAckTimeout = Duration(seconds: 2);

  /// Fresh opens reset the ESP32 (DTR/RTS). Wait for its boot `ready` line.
  static const Duration controllerReadyTimeout = Duration(seconds: 6);

  ProviderSubscription<SerialUiState>? _serialWatch;
  StreamSubscription<String>? _incomingSub;
  Timer? _countdownTimer;
  bool _powerArmed = false;
  bool _tearingDown = false;
  bool _acceptReplies = true;
  bool _arming = false;
  bool _stopInProgress = false;
  bool _failing = false;

  Completer<RelayResponse?>? _pendingReply;
  Completer<void>? _readyWait;
  Future<void> _relayChain = Future<void>.value();

  /// In-flight relay commands, including ones not yet at the head of the queue.
  int _relayBusy = 0;

  /// Incoming-log length before a fresh open, so an old `ready` line is ignored.
  int _readyBaseline = 0;

  SerialController get _serial => ref.read(serialControllerProvider.notifier);

  @override
  ChargingUiState build() {
    ref.onDispose(() {
      unawaited(_tearDown(disconnect: true));
    });
    return ChargingUiState.initial();
  }

  Future<void> startSession() async {
    if (!ref.mounted) {
      return;
    }
    // Allow Retry after a failed session without recreating the provider.
    _tearingDown = false;
    _acceptReplies = true;
    _arming = false;
    _stopInProgress = false;
    _failing = false;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _powerArmed = false;
    _lineBuffer = '';
    _completeWaits();

    final wasConnected = ref.read(serialControllerProvider).isConnected;
    if (!wasConnected) {
      // Drop boot lines from an earlier session before this open.
      _serial.clearIncoming();
      _readyBaseline = 0;
    }

    state = state.copyWith(
      phase: ChargingPhase.connecting,
      secondsRemaining: ChargingUiState.sessionSeconds,
      relayOn: false,
      clearError: true,
      statusMessage: 'Connecting to charging controller…',
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
    if (!ref.mounted || _tearingDown || state.phase == ChargingPhase.error) {
      return;
    }
    await _bindIncoming();
    if (!ref.mounted || _tearingDown || !state.isConnected) {
      return;
    }

    if (!wasConnected) {
      state = state.copyWith(
        statusMessage: 'Waiting for charging controller…',
      );
      final ready = await _waitForControllerReady();
      if (!ref.mounted || _tearingDown || state.phase == ChargingPhase.error) {
        return;
      }
      if (!ready) {
        _enterError(
          statusMessage: 'Charging controller did not become ready',
          lastError: 'No ready message from the controller',
        );
        return;
      }
    }

    // Socket must be confirmed off before the ad gate.
    state = state.copyWith(
      statusMessage: 'Turning the charging socket off…',
    );
    final off = await _requestRelay(on: false);
    if (!ref.mounted || _tearingDown || state.phase == ChargingPhase.error) {
      return;
    }
    if (off == null || !off.confirmsCharging(on: false)) {
      _enterError(
        statusMessage: 'Could not turn off the charging socket',
        lastError: off?.error ??
            state.lastError ??
            'No off confirmation from the controller',
      );
      return;
    }

    state = state.copyWith(
      phase: ChargingPhase.watchingAd,
      relayOn: false,
      clearError: true,
      statusMessage: 'Watch this message to unlock charging',
    );
  }

  /// Called when one sponsored creative finished (or empty-playlist fallback).
  Future<void> onAdCompleted() async {
    if (!ref.mounted ||
        _tearingDown ||
        _arming ||
        _failing ||
        state.phase != ChargingPhase.watchingAd) {
      return;
    }
    _arming = true;
    try {
      if (!state.isConnected) {
        _enterError(
          statusMessage: 'Unable to start charging',
          lastError: 'Lost connection to charging controller',
        );
        return;
      }

      state = state.copyWith(
        phase: ChargingPhase.connecting,
        statusMessage: 'Turning on the charging socket…',
      );
      final reply = await _requestRelay(on: true);
      if (!ref.mounted || _tearingDown) {
        return;
      }
      if (reply != null &&
          reply.confirmsCharging(on: true) &&
          state.phase != ChargingPhase.error) {
        _powerArmed = true;
        state = state.copyWith(
          phase: ChargingPhase.charging,
          relayOn: true,
          secondsRemaining: ChargingUiState.sessionSeconds,
          statusMessage: 'Charging enabled — plug in your phone',
          clearError: true,
        );
        _startCountdown();
        return;
      }

      // Command may have landed without an ack. Force the socket back off.
      final off = await _requestRelay(on: false);
      if (!ref.mounted || _tearingDown) {
        return;
      }
      final confirmedOff = off != null && off.confirmsCharging(on: false);
      if (confirmedOff) {
        state = state.copyWith(relayOn: false);
      }
      if (state.phase == ChargingPhase.error && !state.isConnected) {
        return;
      }
      _enterError(
        statusMessage: 'Could not power the charging socket',
        lastError: reply?.error ??
            state.lastError ??
            'Relay did not confirm on',
        relayOn: confirmedOff ? false : state.relayOn,
      );
    } finally {
      _arming = false;
    }
  }

  Future<void> finishCharging() async {
    if (!ref.mounted ||
        _tearingDown ||
        _stopInProgress ||
        state.phase != ChargingPhase.charging) {
      return;
    }
    _stopInProgress = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    try {
      state = state.copyWith(
        statusMessage: 'Turning off the charging socket…',
      );
      final reply = await _requestRelay(on: false);
      if (!ref.mounted || _tearingDown) {
        return;
      }
      if (reply != null && reply.confirmsCharging(on: false)) {
        _powerArmed = false;
        state = state.copyWith(
          phase: ChargingPhase.done,
          relayOn: false,
          statusMessage: 'Charging finished',
          clearError: true,
        );
        return;
      }
      if (!state.isConnected) {
        _powerArmed = false;
        _enterError(
          statusMessage: 'Charging controller disconnected',
          lastError: 'Could not confirm the socket turned off',
        );
        return;
      }
      _enterError(
        statusMessage: 'Could not turn off the charging socket',
        lastError: reply?.error ??
            state.lastError ??
            'No off confirmation from the controller',
      );
    } finally {
      _stopInProgress = false;
    }
  }

  Future<void> retryConnect() async {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(clearError: true);
    await startSession();
  }

  /// Force relay off + disconnect. Safe to call from session reset.
  Future<void> forceShutdown() => _tearDown(disconnect: true);

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!ref.mounted || _tearingDown) {
        return;
      }
      final next = state.secondsRemaining - 1;
      if (next <= 0) {
        unawaited(finishCharging());
        return;
      }
      state = state.copyWith(secondsRemaining: next);
    });
  }

  /// Send a charging relay command and wait for the matching firmware reply.
  ///
  /// Returns null on write failure, timeout, or a dropped link. A non-null
  /// reply is not success by itself — check [RelayResponse.confirmsCharging].
  Future<RelayResponse?> _requestRelay({required bool on}) {
    _relayBusy++;
    final task = _relayChain.then((_) => _requestRelayUnlocked(on: on));
    _relayChain = task.then((_) {}, onError: (_, _) {});
    return task.whenComplete(() {
      _relayBusy = (_relayBusy - 1).clamp(0, 1 << 30);
    });
  }

  Future<RelayResponse?> _requestRelayUnlocked({required bool on}) async {
    if (_pendingReply != null) {
      return null;
    }

    final service = ref.read(serialServiceProvider);
    if (!service.isConnected) {
      return null;
    }

    final completer = Completer<RelayResponse?>();
    _pendingReply = completer;
    final command = on ? RelayCommands.chargingOn() : RelayCommands.chargingOff();
    try {
      await service.sendLine(command);
      AppLogger.info('Charging relay ${on ? 'ON' : 'OFF'} sent');
    } catch (error) {
      AppLogger.error('Charging relay command failed: $command', error);
      _finishPending(completer, null);
      if (ref.mounted && !_tearingDown) {
        state = state.copyWith(lastError: error.toString());
      }
      return null;
    }

    try {
      return await completer.future.timeout(relayAckTimeout);
    } on TimeoutException {
      AppLogger.error(
        'Charging relay ${on ? 'ON' : 'OFF'} confirmation timed out',
      );
      if (ref.mounted && !_tearingDown) {
        state = state.copyWith(
          lastError: 'No reply from charging controller',
        );
      }
      return null;
    } finally {
      _finishPending(completer, null);
    }
  }

  void _finishPending(Completer<RelayResponse?> completer, RelayResponse? reply) {
    if (identical(_pendingReply, completer)) {
      _pendingReply = null;
    }
    if (!completer.isCompleted) {
      completer.complete(reply);
    }
  }

  void _completeWaits() {
    final pending = _pendingReply;
    if (pending != null && !pending.isCompleted) {
      _pendingReply = null;
      pending.complete(null);
    }
    final ready = _readyWait;
    if (ready != null && !ready.isCompleted) {
      _readyWait = null;
      ready.complete();
    }
  }

  Future<bool> _waitForControllerReady() async {
    if (_seenReady()) {
      return true;
    }
    final completer = Completer<void>();
    _readyWait = completer;
    try {
      if (_seenReady()) {
        return true;
      }
      await completer.future.timeout(controllerReadyTimeout);
    } on TimeoutException {
      return false;
    } finally {
      if (identical(_readyWait, completer)) {
        _readyWait = null;
      }
    }
    if (!ref.mounted || _tearingDown) {
      return false;
    }
    if (state.phase == ChargingPhase.error || !state.isConnected) {
      return false;
    }
    return true;
  }

  bool _seenReady() {
    if (_lineBuffer
        .split(RegExp(r'\r?\n'))
        .any(RelayResponse.isControllerReadyLine)) {
      return true;
    }
    final lines = ref.read(serialControllerProvider).incomingLines;
    final start = _readyBaseline.clamp(0, lines.length);
    return lines.skip(start).any(RelayResponse.isControllerReadyLine);
  }

  Future<void> _failSession({
    required String statusMessage,
    String? lastError,
    bool sendOff = true,
  }) async {
    if (_tearingDown || _failing) {
      return;
    }
    _failing = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _powerArmed = false;
    // Surface the failure in every phase before the off round-trip.
    _enterError(
      statusMessage: statusMessage,
      lastError: lastError,
    );
    try {
      if (!sendOff) {
        if (ref.mounted && !_tearingDown) {
          state = state.copyWith(relayOn: false);
        }
        return;
      }
      final reply = await _requestRelay(on: false);
      if (!ref.mounted || _tearingDown) {
        return;
      }
      if (reply != null && reply.confirmsCharging(on: false)) {
        state = state.copyWith(relayOn: false, clearError: false);
      }
    } finally {
      _failing = false;
    }
  }

  void _enterError({
    required String statusMessage,
    String? lastError,
    bool? relayOn,
  }) {
    if (!ref.mounted || _tearingDown) {
      return;
    }
    state = state.copyWith(
      phase: ChargingPhase.error,
      relayOn: relayOn ?? state.relayOn,
      statusMessage: statusMessage,
      lastError: lastError ?? state.lastError,
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
      );
      return;
    }

    state = state.copyWith(
      connectionStatus: SerialConnectionStatus.connecting,
      statusMessage: 'Looking for charging controller…',
    );

    await _serial.refreshPorts();
    if (!ref.mounted || _tearingDown) {
      return;
    }

    final ports = ref.read(serialControllerProvider).ports;
    if (ports.isEmpty) {
      _enterError(
        statusMessage: 'No charging controller connected',
        lastError: 'No serial controller found. Check the USB cable.',
      );
      state = state.copyWith(connectionStatus: SerialConnectionStatus.error);
      return;
    }

    final preferred = _preferPort(ports);
    _serial.selectPort(preferred);
    await _serial.connect();
    if (!ref.mounted || _tearingDown) {
      return;
    }

    final after = ref.read(serialControllerProvider);
    _syncConnection(after);
    if (!after.isConnected && state.phase != ChargingPhase.error) {
      _enterError(
        statusMessage: 'Unable to connect to charging controller',
        lastError: after.lastError ?? 'Could not open serial port',
      );
      state = state.copyWith(connectionStatus: SerialConnectionStatus.error);
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
    if (!ref.mounted || _tearingDown) {
      return;
    }
    state = state.copyWith(
      connectionStatus: serial.status,
      portName: serial.selectedPortName,
    );

    // Link-loss handling is one-shot. Later serial log updates must not
    // cancel the off command or queue another one.
    if (state.phase == ChargingPhase.error) {
      return;
    }

    final lost = serial.status == SerialConnectionStatus.disconnected ||
        serial.status == SerialConnectionStatus.error;
    if (!lost) {
      return;
    }

    final sessionActive = state.phase == ChargingPhase.charging ||
        state.phase == ChargingPhase.watchingAd ||
        _relayBusy > 0 ||
        _pendingReply != null ||
        _readyWait != null;
    if (!sessionActive) {
      return;
    }

    final mayStillBeOn = _powerArmed || state.relayOn;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _powerArmed = false;
    _completeWaits();
    // A dropped cable does not turn the relay off. Tear-down still sends
    // off and then closes the port, which may reset the ESP32.
    _enterError(
      statusMessage: 'Charging controller disconnected',
      lastError: mayStillBeOn
          ? (serial.lastError ??
              'The socket may still be on until the controller resets.')
          : (serial.lastError ?? 'Serial disconnected'),
    );
    if (ref.read(serialServiceProvider).isConnected) {
      unawaited(_requestRelay(on: false));
    }
  }

  Future<void> _bindIncoming() async {
    if (!ref.mounted) {
      return;
    }
    await _incomingSub?.cancel();
    if (!ref.mounted || _tearingDown) {
      return;
    }
    final service = ref.read(serialServiceProvider);
    _incomingSub = service.incoming.listen(
      _onChunk,
      onError: (Object error) {
        AppLogger.error('Charging serial stream error', error);
        if (!ref.mounted || _tearingDown) {
          return;
        }
        _completeWaits();
        _enterError(
          statusMessage: 'Controller read error',
          lastError: error.toString(),
        );
        state = state.copyWith(
          connectionStatus: SerialConnectionStatus.error,
        );
      },
    );
  }

  String _lineBuffer = '';

  void _onChunk(String chunk) {
    if (!_acceptReplies) {
      return;
    }
    _lineBuffer += chunk;
    while (true) {
      final lf = _lineBuffer.indexOf('\n');
      final cr = _lineBuffer.indexOf('\r');
      var end = -1;
      var skip = 0;
      if (lf >= 0 && cr >= 0) {
        if (cr < lf) {
          end = cr;
          skip = (lf == cr + 1) ? 2 : 1;
        } else {
          end = lf;
          skip = 1;
        }
      } else if (lf >= 0) {
        end = lf;
        skip = 1;
      } else if (cr >= 0) {
        end = cr;
        skip = 1;
      } else {
        break;
      }
      final line = _lineBuffer.substring(0, end).trim();
      _lineBuffer = _lineBuffer.substring(end + skip);
      if (line.isEmpty) {
        continue;
      }
      if (RelayResponse.isControllerReadyLine(line)) {
        final ready = _readyWait;
        if (ready != null && !ready.isCompleted) {
          _readyWait = null;
          ready.complete();
        }
        continue;
      }
      final reply = RelayResponse.tryParse(line);
      if (reply == null) {
        continue;
      }
      _onRelayReply(reply);
    }
  }

  void _onRelayReply(RelayResponse reply) {
    final forCharging = reply.relay == null ||
        reply.relay == RelayCommands.chargingRelayNumber;
    if (!forCharging) {
      return;
    }

    final pending = _pendingReply;
    if (pending != null && !pending.isCompleted) {
      if (ref.mounted &&
          !_tearingDown &&
          reply.ok &&
          reply.relay == RelayCommands.chargingRelayNumber) {
        final confirmedOff =
            reply.isOff && state.phase == ChargingPhase.error;
        state = state.copyWith(
          relayOn: reply.isOn,
          clearError: confirmedOff,
        );
      }
      if (!reply.ok) {
        AppLogger.error(
          'Charging relay error: ${reply.error ?? 'unknown'}',
        );
        if (ref.mounted && !_tearingDown) {
          state = state.copyWith(
            lastError: reply.error ?? 'Relay error',
            statusMessage: 'Charging socket reported an error',
          );
        }
      }
      _finishPending(pending, reply);
      return;
    }

    if (!ref.mounted || _tearingDown) {
      return;
    }

    if (!reply.ok) {
      AppLogger.error(
        'Charging relay error: ${reply.error ?? 'unknown'}',
      );
      final message = reply.error ?? 'Relay error';
      if (state.phase == ChargingPhase.error) {
        state = state.copyWith(lastError: message);
        return;
      }
      // Includes `done`: a late controller error must leave the "socket off" screen.
      unawaited(
        _failSession(
          statusMessage: 'Charging socket reported an error',
          lastError: message,
        ),
      );
      return;
    }

    if (reply.relay != RelayCommands.chargingRelayNumber) {
      return;
    }

    state = state.copyWith(relayOn: reply.isOn);
    if (state.phase == ChargingPhase.charging && reply.isOff) {
      unawaited(
        _failSession(
          statusMessage: 'Charging socket turned off',
          lastError: 'Controller reported the socket is off',
          sendOff: false,
        ),
      );
    } else if (reply.isOn &&
        (state.phase == ChargingPhase.done ||
            state.phase == ChargingPhase.error)) {
      // A late "on" after we stopped must not leave the socket powered.
      unawaited(_requestRelay(on: false));
    }
  }

  Future<void> _tearDown({required bool disconnect}) async {
    if (_tearingDown) {
      return;
    }
    _tearingDown = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _completeWaits();

    try {
      _serialWatch?.close();
    } catch (_) {}
    _serialWatch = null;

    try {
      if (disconnect) {
        // Best-effort off while the reader is still attached, then close.
        // Closing the port may reset the ESP32, which also forces relays off.
        try {
          final service = ref.read(serialServiceProvider);
          if (service.isConnected) {
            await _requestRelay(on: false);
          }
        } catch (_) {}
      }
    } catch (_) {}

    _acceptReplies = false;

    final sub = _incomingSub;
    _incomingSub = null;
    try {
      await sub?.cancel();
    } catch (_) {}

    try {
      if (disconnect) {
        final serialState = ref.read(serialControllerProvider);
        final service = ref.read(serialServiceProvider);
        var closed = false;
        if (serialState.isConnected) {
          try {
            await ref.read(serialControllerProvider.notifier).disconnect();
            closed = !service.isConnected;
          } catch (error) {
            AppLogger.error('Charging serial disconnect failed', error);
          }
        }
        if (!closed && service.isConnected) {
          try {
            await service.sendLine(RelayCommands.chargingOff());
            await service.disconnect(silent: true);
          } catch (_) {}
        }
      }
    } catch (_) {}

    _powerArmed = false;
    _lineBuffer = '';
  }
}
