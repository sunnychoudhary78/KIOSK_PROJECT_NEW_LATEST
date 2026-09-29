/// UI phases for the ad-gated phone charging flow.
enum ChargingPhase {
  /// Opening the ESP32 serial port.
  connecting,

  /// User must watch one sponsored creative.
  watchingAd,

  /// Relay is ON; countdown running.
  charging,

  /// Session finished (time up or user Done).
  done,

  /// Unrecoverable connection / relay failure.
  error,
}
