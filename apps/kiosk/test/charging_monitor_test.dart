import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/charging/application/charging_state.dart';
import 'package:skp_kiosk/features/charging/domain/charger_message.dart';
import 'package:skp_kiosk/features/charging/domain/charging_monitor.dart';
import 'package:skp_kiosk/features/charging/domain/charging_phase.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 29, 12);

  ChargingUiState armed({bool? sensorOk = true}) {
    return ChargingMonitor.onRelayArmed(
      ChargingUiState.initial().copyWith(sensorOk: sensorOk),
    );
  }

  ChargerMessage event(
    ChargerNotice notice, {
    String relayState = 'on',
    double volts = 5,
    double currentMa = 800,
    double powerW = 4,
  }) {
    return ChargerMessage(
      notice: notice,
      relayState: relayState,
      volts: volts,
      currentMa: currentMa,
      powerW: powerW,
    );
  }

  ChargerMessage snapshot({
    bool? ina226 = true,
    String? firmwareState = 'waiting_for_phone',
    bool? plugged = false,
    String? lastResult = 'none',
    String? relayState = 'on',
    double volts = 0.1,
    double currentMa = 0,
    double powerW = 0,
  }) {
    return ChargerMessage(
      notice: ChargerNotice.snapshot,
      ina226: ina226,
      firmwareState: firmwareState,
      plugged: plugged,
      lastResult: lastResult,
      relayState: relayState,
      volts: volts,
      currentMa: currentMa,
      powerW: powerW,
    );
  }

  ChargingUiState apply(ChargingUiState state, ChargerMessage message) {
    return ChargingMonitor.applyMessage(state, message, now: t0);
  }

  group('ChargingMonitor', () {
    test('relay on waits for a phone and does not start the safety cap', () {
      final state = armed();
      expect(state.phase, ChargingPhase.waitingForPhone);
      expect(state.relayOn, isTrue);
      expect(state.chargeStartedAt, isNull);
      expect(state.capSecondsRemaining, isNull);
      expect(state.statusMessage, ChargingCopy.plugIn);
    });

    test('plugged_in starts charging from that moment', () {
      final state = apply(armed(), event(ChargerNotice.pluggedIn));
      expect(state.phase, ChargingPhase.charging);
      expect(state.relayOn, isTrue);
      expect(state.chargeStartedAt, t0);
      expect(state.capSecondsRemaining, ChargingMonitor.maxChargeSeconds);
      expect(state.volts, 5);
      expect(state.currentMa, 800);
      expect(state.powerW, 4);
      expect(state.statusMessage, ChargingCopy.phoneConnected);
    });

    test('a charging snapshot starts the same phase', () {
      final state = apply(
        armed(),
        snapshot(
          firmwareState: 'charging',
          plugged: true,
          lastResult: 'plugged_in',
          powerW: 3.5,
          currentMa: 700,
          volts: 5.1,
        ),
      );
      expect(state.phase, ChargingPhase.charging);
      expect(state.chargeStartedAt, t0);
      expect(state.powerW, 3.5);
    });

    test('stop events end the session with the socket already off', () {
      final charging = apply(armed(), event(ChargerNotice.pluggedIn));

      final unplugged = apply(
        charging,
        event(ChargerNotice.pluggedOut, relayState: 'off', powerW: 0),
      );
      expect(unplugged.phase, ChargingPhase.done);
      expect(unplugged.relayOn, isFalse);
      expect(unplugged.stopReason, ChargingStopReason.pluggedOut);
      expect(unplugged.statusMessage, ChargingStopReason.pluggedOut.detail);

      final full = apply(
        charging,
        event(ChargerNotice.chargeComplete, relayState: 'off', powerW: 0.2),
      );
      expect(full.stopReason, ChargingStopReason.chargeComplete);
      expect(full.relayOn, isFalse);

      final timedOut = apply(
        charging,
        event(ChargerNotice.chargeTimeout, relayState: 'off'),
      );
      expect(timedOut.stopReason, ChargingStopReason.chargeTimeout);
      expect(timedOut.relayOn, isFalse);
    });

    test('a missed stop is recovered from the snapshot last_result', () {
      final charging = apply(armed(), event(ChargerNotice.pluggedIn));
      final done = apply(
        charging,
        snapshot(
          firmwareState: 'relay_off',
          plugged: false,
          lastResult: 'charge_complete',
          relayState: 'off',
        ),
      );
      expect(done.phase, ChargingPhase.done);
      expect(done.stopReason, ChargingStopReason.chargeComplete);
      expect(done.relayOn, isFalse);
    });

    test('host off wins over a snapshot that still says plugged_in', () {
      final charging = apply(armed(), event(ChargerNotice.pluggedIn));
      final stopping = charging.copyWith(hostStopRequested: true);
      final ignored = apply(
        stopping,
        snapshot(
          firmwareState: 'relay_off',
          plugged: false,
          lastResult: 'plugged_in',
          relayState: 'off',
        ),
      );
      expect(identical(ignored, stopping), isTrue);

      final done = ChargingMonitor.onHostRelayOff(stopping);
      expect(done.phase, ChargingPhase.done);
      expect(done.stopReason, ChargingStopReason.userStop);
      expect(done.relayOn, isFalse);
      expect(done.hostStopRequested, isFalse);
      expect(done.statusMessage, ChargingStopReason.userStop.detail);
    });

    test('INA down does not invent a charging phase', () {
      final waiting = armed(sensorOk: false);
      expect(waiting.phase, ChargingPhase.waitingForPhone);
      expect(waiting.sensorLost, isTrue);
      expect(waiting.statusMessage, ChargingCopy.sensorUnavailable);

      final stillWaiting = apply(
        waiting,
        snapshot(
          ina226: false,
          firmwareState: 'charging',
          plugged: true,
          relayState: 'on',
          lastResult: 'none',
        ),
      );
      expect(stillWaiting.phase, ChargingPhase.waitingForPhone);
      expect(stillWaiting.sensorLost, isTrue);
      expect(stillWaiting.chargeStartedAt, isNull);
    });

    test('sensor loss while charging keeps the phone session', () {
      final charging = apply(armed(), event(ChargerNotice.pluggedIn));
      final lost = apply(charging, event(ChargerNotice.ina226Error));
      expect(lost.phase, ChargingPhase.charging);
      expect(lost.sensorLost, isTrue);
      expect(lost.relayOn, isTrue);
      expect(lost.statusMessage, ChargingCopy.sensorLost);
      expect(lost.chargeStartedAt, t0);

      final ready = apply(lost, event(ChargerNotice.ina226Ready));
      expect(ready.phase, ChargingPhase.charging);
      expect(ready.sensorLost, isFalse);
      expect(ready.statusMessage, ChargingCopy.phoneConnected);
    });

    test('the safety cap reaching zero does not end charging', () {
      final charging = apply(armed(), event(ChargerNotice.pluggedIn));
      final atCap = ChargingMonitor.refreshCap(
        charging,
        t0.add(const Duration(minutes: ChargingMonitor.maxChargeMinutes)),
      );
      expect(atCap.phase, ChargingPhase.charging);
      expect(atCap.capSecondsRemaining, 0);
      expect(atCap.relayOn, isTrue);
      expect(atCap.statusMessage, ChargingCopy.finishingCap);

      final same = ChargingMonitor.refreshCap(
        atCap,
        t0.add(const Duration(minutes: ChargingMonitor.maxChargeMinutes)),
      );
      expect(identical(same, atCap), isTrue);
    });

    test('events before the socket is on are ignored', () {
      final watching = ChargingUiState.initial().copyWith(
        phase: ChargingPhase.watchingAd,
      );
      final next = apply(watching, event(ChargerNotice.pluggedIn));
      expect(identical(next, watching), isTrue);
    });

    test('an unsolicited relay-off ends without asking for another off', () {
      final waiting = armed();
      final done = ChargingMonitor.onUnsolicitedRelayOff(waiting);
      expect(done.phase, ChargingPhase.done);
      expect(done.stopReason, ChargingStopReason.socketOff);
      expect(done.relayOn, isFalse);
    });

    test('a ready line after arm is a controller reset', () {
      final waiting = armed();
      final reset = ChargingMonitor.onControllerReset(waiting);
      expect(reset.phase, ChargingPhase.error);
      expect(reset.relayOn, isFalse);
      expect(reset.statusMessage, 'Charging controller reset');
    });

    test('relay_off with the relay still on stays waiting', () {
      final waiting = apply(
        armed(),
        snapshot(
          firmwareState: 'relay_off',
          relayState: 'on',
          plugged: false,
          lastResult: 'none',
        ),
      );
      expect(waiting.phase, ChargingPhase.waitingForPhone);
      expect(waiting.relayOn, isTrue);
    });
  });
}
