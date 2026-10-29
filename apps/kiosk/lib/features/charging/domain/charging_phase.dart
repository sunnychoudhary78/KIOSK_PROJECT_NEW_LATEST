/// UI phases for the ad-gated phone charging flow.
enum ChargingPhase {
  /// Opening the ESP32 serial port.
  connecting,

  /// User must watch one sponsored creative before Relay 1 turns on.
  watchingAd,

  /// Relay 1 is on. Firmware is waiting for the phone to draw power.
  waitingForPhone,

  /// Phone is drawing power. Firmware owns unplug, full, and the 4-hour cap.
  charging,

  /// Socket is off (visitor, unplug, full, or the firmware safety cap).
  done,

  /// Unrecoverable connection / relay failure, or the controller reset.
  error,
}

/// Why a charging session ended with the socket off.
enum ChargingStopReason {
  /// Visitor tapped Done. Host sent relay off. Firmware emits no charger event.
  userStop,

  /// Firmware `plugged_out`: cable pulled, Relay 1 already off.
  pluggedOut,

  /// Firmware `charge_complete`: charge tapered off, Relay 1 already off.
  chargeComplete,

  /// Firmware `charge_timeout`: 240 minutes after plug-in, Relay 1 already off.
  chargeTimeout,

  /// Relay read-back went off without a charger stop event.
  socketOff,
}

/// Visitor-facing lines for [ChargingStopReason].
extension ChargingStopReasonCopy on ChargingStopReason {
  String get title => switch (this) {
    ChargingStopReason.userStop => 'Charging finished',
    ChargingStopReason.pluggedOut => 'Phone unplugged',
    ChargingStopReason.chargeComplete => 'Phone is fully charged',
    ChargingStopReason.chargeTimeout => 'Charging time limit reached',
    ChargingStopReason.socketOff => 'The socket is off',
  };

  String get detail => switch (this) {
    ChargingStopReason.userStop => 'The socket is off.',
    ChargingStopReason.pluggedOut => 'Phone unplugged. The socket is off.',
    ChargingStopReason.chargeComplete =>
      'Phone is fully charged. The socket is off.',
    ChargingStopReason.chargeTimeout =>
      'The 4-hour limit was reached. The socket is off.',
    ChargingStopReason.socketOff => 'The socket is off.',
  };
}

/// Status lines shared by the monitor and the charging screen.
abstract final class ChargingCopy {
  static const plugIn = 'Plug in your phone';
  static const phoneConnected = 'Phone connected';
  static const sensorUnavailable =
      'Plug detection is unavailable. The socket stays on until you tap Done.';
  static const sensorLost =
      'Charger sensor lost. The socket stays on until you tap Done.';
  static const finishingCap = 'Finishing the safety limit…';
}
