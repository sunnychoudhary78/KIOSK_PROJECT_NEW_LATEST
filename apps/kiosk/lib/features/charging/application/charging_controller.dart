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
  ProviderSubscription<SerialUiState>? _serialWatch;
  StreamSubscription<String>? _incomingSub;
  Timer? _countdownTimer;
  bool _powerArmed = false;
  bool _tearingDown = false;

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
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _powerArmed = false;
    _lineBuffer = '';

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
    if (!ref.mounted || _tearingDown) {
      return;
    }
    await _bindIncoming();
    if (!ref.mounted || _tearingDown) {
      return;
    }

    if (state.isConnected) {
      // Ensure socket is cold before the ad gate.
      await _sendRelay(on: false, silent: true);
      if (!ref.mounted || _tearingDown) {
        return;
      }
      state = state.copyWith(
        phase: ChargingPhase.watchingAd,
        statusMessage: 'Watch this message to unlock charging',
      );
    }
  }

  /// Called when one sponsored creative finished (or empty-playlist fallback).
  Future<void> onAdCompleted() async {
    if (!ref.mounted ||
        _tearingDown ||
        state.phase != ChargingPhase.watchingAd) {
      return;
    }
    if (!state.isConnected) {
      state = state.copyWith(
        phase: ChargingPhase.error,
        lastError: 'Lost connection to charging controller',
        statusMessage: 'Unable to start charging',
      );
      return;
    }

    final ok = await _sendRelay(on: true);
    if (!ref.mounted || _tearingDown) {
      return;
    }
    if (!ok) {
      state = state.copyWith(
        phase: ChargingPhase.error,
        lastError: state.lastError ?? 'Relay did not turn on',
        statusMessage: 'Could not power the charging socket',
      );
      return;
    }

    _powerArmed = true;
    state = state.copyWith(
      phase: ChargingPhase.charging,
      relayOn: true,
      secondsRemaining: ChargingUiState.sessionSeconds,
      statusMessage: 'Charging enabled — plug in your phone',
      clearError: true,
    );
    _startCountdown();
  }

  Future<void> finishCharging() async {
    await _stopPower(reason: 'done');
    if (ref.mounted) {
      state = state.copyWith(
        phase: ChargingPhase.done,
        statusMessage: 'Charging finished',
      );
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
      if (!ref.mounted) {
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

  Future<bool> _sendRelay({required bool on, bool silent = false}) async {
    if (!ref.mounted) {
      return false;
    }
    final serial = ref.read(serialControllerProvider);
    if (!serial.isConnected) {
      if (!silent) {
        state = state.copyWith(lastError: 'Serial not connected');
      }
      return false;
    }
    final command = on ? RelayCommands.chargingOn() : RelayCommands.chargingOff();
    try {
      await _serial.sendLine(command);
      AppLogger.info('Charging relay ${on ? 'ON' : 'OFF'} sent');
      if (ref.mounted) {
        state = state.copyWith(relayOn: on);
      }
      return true;
    } catch (error) {
      AppLogger.error('Charging relay command failed: $command', error);
      if (!silent && ref.mounted) {
        state = state.copyWith(lastError: error.toString());
      }
      return false;
    }
  }

  Future<void> _stopPower({required String reason}) async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_powerArmed || state.relayOn) {
      await _sendRelay(on: false, silent: true);
      _powerArmed = false;
      AppLogger.info('Charging power stopped ($reason)');
    }
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
      state = state.copyWith(
        phase: ChargingPhase.error,
        connectionStatus: SerialConnectionStatus.error,
        lastError: 'No serial controller found. Check the USB cable.',
        statusMessage: 'No charging controller connected',
      );
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
    if (!after.isConnected) {
      state = state.copyWith(
        phase: ChargingPhase.error,
        connectionStatus: SerialConnectionStatus.error,
        lastError: after.lastError ?? 'Could not open serial port',
        statusMessage: 'Unable to connect to charging controller',
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
    if (!ref.mounted || _tearingDown) {
      return;
    }
    state = state.copyWith(
      connectionStatus: serial.status,
      portName: serial.selectedPortName,
      lastError: serial.lastError,
      clearError: serial.lastError == null,
    );

    if (serial.status == SerialConnectionStatus.disconnected ||
        serial.status == SerialConnectionStatus.error) {
      if (state.phase == ChargingPhase.charging ||
          state.phase == ChargingPhase.watchingAd) {
        _countdownTimer?.cancel();
        _powerArmed = false;
        state = state.copyWith(
          phase: ChargingPhase.error,
          relayOn: false,
          statusMessage: 'Charging controller disconnected',
          lastError: serial.lastError ?? 'Serial disconnected',
        );
      }
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
        if (!ref.mounted) {
          return;
        }
        state = state.copyWith(
          phase: ChargingPhase.error,
          connectionStatus: SerialConnectionStatus.error,
          lastError: error.toString(),
          statusMessage: 'Controller read error',
        );
      },
    );
  }

  String _lineBuffer = '';

  void _onChunk(String chunk) {
    if (!ref.mounted || _tearingDown) {
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
      final reply = RelayResponse.tryParse(line);
      if (reply == null) {
        continue;
      }
      if (!reply.ok) {
        AppLogger.error(
          'Charging relay error: ${reply.error ?? 'unknown'}',
        );
        if (ref.mounted && state.phase == ChargingPhase.charging) {
          state = state.copyWith(
            lastError: reply.error ?? 'Relay error',
            statusMessage: 'Charging socket reported an error',
          );
        }
      } else if (reply.relay == RelayCommands.chargingRelayNumber) {
        if (ref.mounted) {
          state = state.copyWith(relayOn: reply.isOn);
        }
      }
    }
  }

  Future<void> _tearDown({required bool disconnect}) async {
    if (_tearingDown) {
      return;
    }
    _tearingDown = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;

    try {
      _serialWatch?.close();
    } catch (_) {}
    _serialWatch = null;

    final sub = _incomingSub;
    _incomingSub = null;
    try {
      await sub?.cancel();
    } catch (_) {}

    try {
      if (disconnect) {
        final serialState = ref.read(serialControllerProvider);
        if (serialState.isConnected) {
          try {
            await ref
                .read(serialControllerProvider.notifier)
                .sendLine(RelayCommands.chargingOff());
          } catch (_) {}
          try {
            await ref.read(serialControllerProvider.notifier).disconnect();
          } catch (error) {
            AppLogger.error('Charging serial disconnect failed', error);
          }
        } else {
          // Best-effort via service if UI state is already torn down.
          try {
            final service = ref.read(serialServiceProvider);
            if (service.isConnected) {
              await service.sendLine(RelayCommands.chargingOff());
              await service.disconnect(silent: true);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    _powerArmed = false;
    _lineBuffer = '';
  }
}
