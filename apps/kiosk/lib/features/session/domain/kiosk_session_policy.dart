/// Kiosk idle session policies (timeout, reset). Expand as needed.
class KioskSessionPolicy {
  const KioskSessionPolicy({this.idleTimeout = const Duration(minutes: 2)});

  final Duration idleTimeout;
}
