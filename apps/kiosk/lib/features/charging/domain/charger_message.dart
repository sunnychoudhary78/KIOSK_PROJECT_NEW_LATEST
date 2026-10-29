import 'dart:convert';

import 'package:skp_kiosk/core/hardware/serial/relay_command.dart';

/// One INA226 charger line from the ESP32.
///
/// Events (`plugged_in`, `plugged_out`, `charge_complete`, `charge_timeout`,
/// `ina226_error`, `ina226_ready`) and the `{"command":"charger"}` snapshot
/// (`charger` = `status`). `debug`, `ina226_connected`,
/// `ina226_not_connected`, and `i2c_found` are ignored.
enum ChargerNotice {
  pluggedIn,
  pluggedOut,
  chargeComplete,
  chargeTimeout,
  ina226Error,
  ina226Ready,
  snapshot,
}

class ChargerMessage {
  const ChargerMessage({
    required this.notice,
    this.ina226,
    this.firmwareState,
    this.plugged,
    this.lastResult,
    this.relayState,
    this.volts,
    this.currentMa,
    this.powerW,
  });

  final ChargerNotice notice;

  /// Present on snapshots (`ina226` bool).
  final bool? ina226;

  /// Snapshot `state`: `charging`, `waiting_for_phone`, or `relay_off`.
  final String? firmwareState;

  final bool? plugged;

  /// Snapshot `last_result`.
  final String? lastResult;

  /// `relay_state` on events and snapshots: `on` or `off`.
  final String? relayState;

  final double? volts;
  final double? currentMa;
  final double? powerW;

  /// Parses a charger JSON line. Returns null for anything the UI ignores.
  static ChargerMessage? tryParse(String line) {
    final json = _decodeObject(line);
    if (json == null || !json.containsKey('charger')) {
      return null;
    }

    final notice = switch (json['charger']?.toString()) {
      'plugged_in' => ChargerNotice.pluggedIn,
      'plugged_out' => ChargerNotice.pluggedOut,
      'charge_complete' => ChargerNotice.chargeComplete,
      'charge_timeout' => ChargerNotice.chargeTimeout,
      'ina226_error' => ChargerNotice.ina226Error,
      'ina226_ready' => ChargerNotice.ina226Ready,
      'status' => ChargerNotice.snapshot,
      _ => null,
    };
    if (notice == null) {
      return null;
    }

    return ChargerMessage(
      notice: notice,
      ina226: _asBool(json['ina226']),
      firmwareState: json['state']?.toString(),
      plugged: _asBool(json['plugged']),
      lastResult: json['last_result']?.toString(),
      relayState: json['relay_state']?.toString(),
      volts: _asDouble(json['volts']),
      currentMa: _asDouble(json['current_ma']),
      powerW: _asDouble(json['power_w']),
    );
  }

  /// `ina226` on the boot `{"status":"ready",...}` line.
  ///
  /// Null when the line is not ready, or when this firmware build omitted
  /// the field.
  static bool? ina226FromReadyLine(String line) {
    if (!RelayResponse.isControllerReadyLine(line)) {
      return null;
    }
    final json = _decodeObject(line);
    if (json == null || !json.containsKey('ina226')) {
      return null;
    }
    return _asBool(json['ina226']);
  }

  static Map<String, dynamic>? _decodeObject(String line) {
    final normalized = line.trim();
    if (normalized.isEmpty ||
        !normalized.startsWith('{') ||
        !normalized.endsWith('}')) {
      return null;
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) {
        return null;
      }
      return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
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

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
