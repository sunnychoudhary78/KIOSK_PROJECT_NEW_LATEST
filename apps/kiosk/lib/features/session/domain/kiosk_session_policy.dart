/// Timeouts for a kiosk visitor session (ATM-style inactivity reset).
class KioskSessionPolicy {
  const KioskSessionPolicy({
    this.idleTimeout = const Duration(minutes: 2),
    this.warningDuration = const Duration(seconds: 10),
    this.consentIdleTimeout = const Duration(minutes: 4),
  });

  /// Inactivity on a service screen before the "still there?" warning.
  final Duration idleTimeout;

  /// Countdown shown after [idleTimeout] before wiping and returning home.
  final Duration warningDuration;

  /// Longer idle while DigiLocker WebView2 is showing consent (pointer events
  /// often do not bubble out of the native view).
  final Duration consentIdleTimeout;
}
