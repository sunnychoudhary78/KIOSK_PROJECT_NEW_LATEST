import 'dart:convert';

/// ESP32 relay JSON protocol (same USB controller as Well Being sensors).
///
/// Command: `{"relay":1,"state":"on"}` / `"off"`
/// Reply:   `{"ok":true,"relay":1,"state":"on"}` or `{"ok":false,"error":…}`
class RelayCommands {
  RelayCommands._();

  /// Charging socket on the kiosk cabinet. Switch to 2 if hardware uses Relay 2.
  static const int chargingRelayNumber = 1;

  static String setState({required int relay, required bool on}) {
    final state = on ? 'on' : 'off';
    return '{"relay":$relay,"state":"$state"}';
  }

  static String chargingOn() =>
      setState(relay: chargingRelayNumber, on: true);

  static String chargingOff() =>
      setState(relay: chargingRelayNumber, on: false);
}

/// Parsed relay reply from firmware.
class RelayResponse {
  const RelayResponse({
    required this.ok,
    this.relay,
    this.state,
    this.error,
  });

  final bool ok;
  final int? relay;
  final String? state;
  final String? error;

  bool get isOn => state == 'on';
  bool get isOff => state == 'off';

  static RelayResponse? tryParse(String line) {
    final normalized = line.trim();
    if (normalized.isEmpty ||
        !normalized.startsWith('{') ||
        !normalized.endsWith('}')) {
      return null;
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        return null;
      }
      json = decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }

    // Sensor status / result lines are not relay replies.
    if (json.containsKey('status') ||
        json.containsKey('bpm') ||
        json.containsKey('spo2') ||
        json.containsKey('command')) {
      return null;
    }

    final hasRelay = json.containsKey('relay');
    final hasOk = json.containsKey('ok');
    final hasError = json.containsKey('error');
    if (!hasOk && !hasRelay && !hasError) {
      return null;
    }
    // Require ok or an explicit relay field so random JSON is ignored.
    if (!hasOk && !hasRelay) {
      return null;
    }

    return RelayResponse(
      ok: _asBool(json['ok']) ?? false,
      relay: _asInt(json['relay']),
      state: json['state']?.toString(),
      error: json['error']?.toString(),
    );
  }

  static bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') {
        return true;
      }
      if (lower == 'false' || lower == '0') {
        return false;
      }
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
