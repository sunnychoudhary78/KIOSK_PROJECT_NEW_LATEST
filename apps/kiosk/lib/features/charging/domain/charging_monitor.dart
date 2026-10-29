import 'package:skp_kiosk/features/charging/application/charging_state.dart';
import 'package:skp_kiosk/features/charging/domain/charger_message.dart';
import 'package:skp_kiosk/features/charging/domain/charging_phase.dart';

/// Pure mirror of the ESP32 charger monitor in
/// `firmware/sppc_controller/kiosk_temp_update_16.ino`.
///
/// Watt thresholds stay on the device. This only applies `charger` events,
/// `{"command":"charger"}` snapshots, and host relay results.
abstract final class ChargingMonitor {
  /// Firmware `CHARGER_MAX_MINUTES`. Display only — `charge_timeout` ends
  /// the session.
  static const int maxChargeMinutes = 240;
  static const int maxChargeSeconds = maxChargeMinutes * 60;

  /// Relay 1 just confirmed on.
  static ChargingUiState onRelayArmed(ChargingUiState state) {
    final sensorDown = state.sensorOk == false;
    return state.copyWith(
      phase: ChargingPhase.waitingForPhone,
      relayOn: true,
      sensorLost: sensorDown,
      hostStopRequested: false,
      clearChargeStarted: true,
      clearCap: true,
      clearStopReason: true,
      clearError: true,
      statusMessage: sensorDown
          ? ChargingCopy.sensorUnavailable
          : ChargingCopy.plugIn,
    );
  }

  /// Host relay-off ack. Firmware does not emit a charger event for this.
  static ChargingUiState onHostRelayOff(ChargingUiState state) {
    if (state.phase == ChargingPhase.done &&
        state.stopReason != null &&
        state.stopReason != ChargingStopReason.userStop) {
      return state.copyWith(relayOn: false, hostStopRequested: false);
    }
    return _finish(state, ChargingStopReason.userStop);
  }

  /// A relay JSON line reported off while we still considered the socket on.
  /// Firmware auto-stop does not use this path; it sends a charger event.
  static ChargingUiState onUnsolicitedRelayOff(ChargingUiState state) {
    if (!state.socketArmed) {
      return state;
    }
    return _finish(state, ChargingStopReason.socketOff);
  }

  /// A later `{"status":"ready"}` means the ESP32 rebooted and relays are off.
  static ChargingUiState onControllerReset(ChargingUiState state) {
    return state.copyWith(
      phase: ChargingPhase.error,
      relayOn: false,
      hostStopRequested: false,
      sensorLost: false,
      clearChargeStarted: true,
      clearCap: true,
      clearStopReason: true,
      statusMessage: 'Charging controller reset',
      lastError: 'The socket turned off when the controller restarted.',
    );
  }

  /// Updates the on-screen cap. Does not change phase and does not turn
  /// the socket off when the cap reaches zero.
  static ChargingUiState refreshCap(ChargingUiState state, DateTime now) {
    if (state.phase != ChargingPhase.charging ||
        state.chargeStartedAt == null) {
      return state;
    }
    final elapsed = now.difference(state.chargeStartedAt!).inSeconds;
    if (elapsed < 0) {
      return state;
    }
    final remaining = elapsed >= maxChargeSeconds
        ? 0
        : maxChargeSeconds - elapsed;
    if (remaining == state.capSecondsRemaining) {
      return state;
    }
    return state.copyWith(
      capSecondsRemaining: remaining,
      statusMessage: remaining == 0 && !state.sensorLost
          ? ChargingCopy.finishingCap
          : null,
    );
  }

  static ChargingUiState applyMessage(
    ChargingUiState state,
    ChargerMessage message, {
    required DateTime now,
  }) {
    if (state.hostStopRequested) {
      return state;
    }
    if (!state.socketArmed) {
      return state;
    }

    final withReadings = _withReadings(state, message);
    return switch (message.notice) {
      ChargerNotice.pluggedIn => _enterCharging(withReadings, now),
      ChargerNotice.pluggedOut => _finish(
        withReadings,
        ChargingStopReason.pluggedOut,
      ),
      ChargerNotice.chargeComplete => _finish(
        withReadings,
        ChargingStopReason.chargeComplete,
      ),
      ChargerNotice.chargeTimeout => _finish(
        withReadings,
        ChargingStopReason.chargeTimeout,
      ),
      ChargerNotice.ina226Error => withReadings.copyWith(
        sensorOk: false,
        sensorLost: true,
        statusMessage: ChargingCopy.sensorLost,
      ),
      ChargerNotice.ina226Ready => _onSensorReady(withReadings),
      ChargerNotice.snapshot => _applySnapshot(withReadings, message, now),
    };
  }

  static ChargingUiState _onSensorReady(ChargingUiState state) {
    final cleared = state.copyWith(sensorOk: true, sensorLost: false);
    if (cleared.phase == ChargingPhase.charging) {
      final finishing = cleared.capSecondsRemaining == 0;
      return cleared.copyWith(
        statusMessage: finishing
            ? ChargingCopy.finishingCap
            : ChargingCopy.phoneConnected,
      );
    }
    return cleared.copyWith(statusMessage: ChargingCopy.plugIn);
  }

  static ChargingUiState _applySnapshot(
    ChargingUiState state,
    ChargerMessage message,
    DateTime now,
  ) {
    if (message.ina226 == false) {
      final lost = state.copyWith(
        sensorOk: false,
        sensorLost: true,
        statusMessage: state.phase == ChargingPhase.charging
            ? ChargingCopy.sensorLost
            : ChargingCopy.sensorUnavailable,
      );
      if (message.relayState == 'off') {
        return _finishFromLastResult(lost, message.lastResult);
      }
      // Firmware never enters charging while the INA226 is down, and a
      // mid-charge sensor loss keeps the previous charger state. Do not
      // invent a charging phase from this snapshot.
      if (state.phase == ChargingPhase.charging) {
        return lost;
      }
      return lost.copyWith(phase: ChargingPhase.waitingForPhone, relayOn: true);
    }

    var next = state;
    if (message.ina226 == true) {
      next = next.copyWith(sensorOk: true, sensorLost: false);
    }

    final firmwareState = message.firmwareState;
    if (firmwareState == 'charging' || message.plugged == true) {
      return _enterCharging(next, now);
    }
    if (firmwareState == 'waiting_for_phone') {
      return _enterWaiting(next);
    }
    // Relay just turned on: the monitor is still `relay_off` until the
    // next poll moves it to `waiting_for_phone`. A phone that is already
    // charging must not be dropped by that in-between snapshot.
    if (message.relayState == 'on') {
      if (state.phase == ChargingPhase.charging) {
        return next;
      }
      return _enterWaiting(next);
    }
    if (message.relayState == 'off' || firmwareState == 'relay_off') {
      return _finishFromLastResult(next, message.lastResult);
    }
    return next;
  }

  static ChargingUiState _enterWaiting(ChargingUiState state) {
    return state.copyWith(
      phase: ChargingPhase.waitingForPhone,
      relayOn: true,
      clearChargeStarted: true,
      clearCap: true,
      clearStopReason: true,
      statusMessage: state.sensorLost
          ? ChargingCopy.sensorUnavailable
          : ChargingCopy.plugIn,
    );
  }

  static ChargingUiState _enterCharging(ChargingUiState state, DateTime now) {
    final started = state.chargeStartedAt ?? now;
    final elapsed = now.difference(started).inSeconds;
    final remaining = elapsed <= 0
        ? maxChargeSeconds
        : (elapsed >= maxChargeSeconds ? 0 : maxChargeSeconds - elapsed);
    return state.copyWith(
      phase: ChargingPhase.charging,
      relayOn: true,
      sensorOk: true,
      sensorLost: false,
      chargeStartedAt: started,
      capSecondsRemaining: remaining,
      clearStopReason: true,
      statusMessage: remaining == 0
          ? ChargingCopy.finishingCap
          : ChargingCopy.phoneConnected,
    );
  }

  static ChargingUiState _finishFromLastResult(
    ChargingUiState state,
    String? lastResult,
  ) {
    final reason = switch (lastResult) {
      'plugged_out' => ChargingStopReason.pluggedOut,
      'charge_complete' => ChargingStopReason.chargeComplete,
      'charge_timeout' => ChargingStopReason.chargeTimeout,
      _ => ChargingStopReason.socketOff,
    };
    return _finish(state, reason);
  }

  static ChargingUiState _finish(
    ChargingUiState state,
    ChargingStopReason reason,
  ) {
    return state.copyWith(
      phase: ChargingPhase.done,
      relayOn: false,
      hostStopRequested: false,
      sensorLost: false,
      stopReason: reason,
      clearChargeStarted: true,
      clearCap: true,
      clearError: true,
      statusMessage: reason.detail,
    );
  }

  static ChargingUiState _withReadings(
    ChargingUiState state,
    ChargerMessage message,
  ) {
    return state.copyWith(
      volts: message.volts,
      currentMa: message.currentMa,
      powerW: message.powerW,
    );
  }
}
