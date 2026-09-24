import 'dart:convert';

/// Parser for the ESP32 dual-sensor USB Serial JSON protocol (v2 firmware).
///
/// Commands (kiosk → device):
/// `{"command":"start","sensor":"max30102"|"mlx90614"|"all"}`
/// `{"command":"stop"}`
///
/// Status lines:
/// `{"status":"ready","max30102":true,"mlx90614":true}`
/// `{"status":"place_finger"}` / `finger_detected` / `sensor_started`
/// `{"status":"recording","sensor":"max30102","elapsed":3,"remaining":17}`
/// `{"status":"aborted","reason":"finger_removed"}`
///
/// Final result (`status` is `complete` on current firmware; omitted on older builds):
/// `{"status":"complete","bpm":75.0,"spo2":98.0,"object_f":97.5,"ambient_f":75.2}`
/// (any field may be null when that sensor was not in the session)
class VitalsLineParser {
  VitalsLineParser();

  String _buffer = '';

  static const double minHeartRate = 30;
  static const double maxHeartRate = 220;
  static const double minSpO2 = 70;
  static const double maxSpO2 = 100;
  static const double minCaptureTempC = 30;
  static const double maxCaptureTempC = 43;

  static const int maxCollectionSeconds = 20;
  static const int tempCollectionSeconds = 30;

  /// Feed a raw UTF-8 chunk; returns one result per complete line.
  List<VitalsParseResult> addChunk(String chunk) {
    if (chunk.isEmpty) {
      return const [];
    }

    final results = <VitalsParseResult>[];
    _buffer += chunk;

    while (true) {
      final lf = _buffer.indexOf('\n');
      final cr = _buffer.indexOf('\r');
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

      final line = _buffer.substring(0, end).trim();
      _buffer = _buffer.substring(end + skip);
      if (line.isEmpty) {
        continue;
      }
      final parsed = parseLine(line);
      if (parsed != null) {
        results.add(parsed);
      }
    }

    return results;
  }

  void reset() {
    _buffer = '';
  }

  /// Parse one complete line (tests + direct use).
  VitalsParseResult? parseLine(String line) {
    final normalized = line.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (!normalized.startsWith('{') || !normalized.endsWith('}')) {
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

    final status = json['status']?.toString();
    if (status == 'complete') {
      return _parseResult(json, normalized);
    }
    if (status != null && status.isNotEmpty) {
      return _parseStatus(status, json, normalized);
    }

    // Ignore legacy stream protocol (`mode`/`st`).
    if (json.containsKey('mode') || json.containsKey('st')) {
      return null;
    }

    // Legacy final result: bpm/spo2/object_f/ambient_f and no status.
    if (json.containsKey('bpm') ||
        json.containsKey('spo2') ||
        json.containsKey('object_f') ||
        json.containsKey('ambient_f')) {
      return _parseResult(json, normalized);
    }

    return null;
  }

  VitalsParseResult _parseStatus(
    String status,
    Map<String, dynamic> json,
    String raw,
  ) {
    final sensor = json['sensor']?.toString().toLowerCase();
    final reason = json['reason']?.toString();
    final elapsed = _asInt(json['elapsed']);
    final remaining = _asInt(json['remaining']);
    final maxOk = _asBool(json['max30102']);
    final tempOk = _asBool(json['mlx90614']);

    switch (status) {
      case 'ready':
        return VitalsParseResult(
          kind: VitalsMessageKind.ready,
          status: status,
          max30102Ok: maxOk,
          mlx90614Ok: tempOk,
          rawLine: raw,
        );
      case 'place_finger':
        return VitalsParseResult(
          kind: VitalsMessageKind.placeFinger,
          status: status,
          finger: false,
          fingerAbsent: true,
          rawLine: raw,
        );
      case 'finger_detected':
        return VitalsParseResult(
          kind: VitalsMessageKind.fingerDetected,
          status: status,
          finger: true,
          fingerAbsent: false,
          rawLine: raw,
        );
      case 'sensor_started':
        return VitalsParseResult(
          kind: VitalsMessageKind.sensorStarted,
          status: status,
          finger: true,
          fingerAbsent: false,
          rawLine: raw,
        );
      case 'recording':
        return VitalsParseResult(
          kind: VitalsMessageKind.recording,
          status: status,
          sensor: sensor,
          elapsedSeconds: elapsed,
          remSeconds: remaining?.toDouble(),
          finger: sensor == 'max30102' ? true : null,
          fingerAbsent: false,
          rawLine: raw,
        );
      case 'aborted':
        return VitalsParseResult(
          kind: VitalsMessageKind.aborted,
          status: status,
          abortReason: reason,
          errorMessage: reason,
          fingerAbsent: reason == 'finger_removed',
          rawLine: raw,
        );
      case 'max30102_not_found':
      case 'mlx90614_not_found':
      case 'no_sensor_requested':
      case 'unknown_sensor':
      case 'unknown_command':
      case 'session_in_progress':
        return VitalsParseResult(
          kind: VitalsMessageKind.error,
          status: status,
          errorMessage: status,
          rawLine: raw,
        );
      case 'already_idle':
        return VitalsParseResult(
          kind: VitalsMessageKind.info,
          status: status,
          infoMessage: status,
          rawLine: raw,
        );
      default:
        return VitalsParseResult(
          kind: VitalsMessageKind.info,
          status: status,
          infoMessage: status,
          rawLine: raw,
        );
    }
  }

  VitalsParseResult _parseResult(Map<String, dynamic> json, String raw) {
    final bpm = _sanitizeHeartRate(_asNullableDouble(json['bpm']));
    final spo2 = _sanitizeSpO2(_asNullableDouble(json['spo2']));
    final objectF = _asNullableDouble(json['object_f']);
    final ambientF = _asNullableDouble(json['ambient_f']);

    double? tempF;
    double? tempC;
    if (objectF != null) {
      tempF = objectF;
      tempC = (objectF - 32) * 5 / 9;
      if (tempC < -40 || tempC > 100) {
        tempC = null;
        tempF = null;
      }
    }

    final hasOxi = bpm != null || spo2 != null;
    final hasTemp = tempC != null;

    return VitalsParseResult(
      kind: VitalsMessageKind.result,
      heartRate: bpm,
      spo2: spo2,
      finalHeartRate: bpm,
      finalSpO2: spo2,
      temperatureC: tempC,
      temperatureF: tempF,
      ambientTempF: ambientF,
      canCaptureTemp: hasTemp &&
          tempC >= minCaptureTempC &&
          tempC <= maxCaptureTempC,
      ok: hasOxi || hasTemp,
      rawLine: raw,
    );
  }

  static double? _sanitizeHeartRate(double? value) {
    if (value == null || value <= 0) {
      return null;
    }
    if (value < minHeartRate || value > maxHeartRate) {
      return null;
    }
    return value;
  }

  static double? _sanitizeSpO2(double? value) {
    if (value == null || value <= 0) {
      return null;
    }
    if (value < minSpO2 || value > maxSpO2) {
      return null;
    }
    return value;
  }

  /// JSON null → null; numbers/strings parsed.
  static double? _asNullableDouble(Object? value) {
    if (value == null) {
      return null;
    }
    return _asDouble(value);
  }

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      if (value.toLowerCase() == 'null') {
        return null;
      }
      return double.tryParse(value);
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
      return int.tryParse(value) ?? double.tryParse(value)?.round();
    }
    return null;
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
}

enum VitalsMessageKind {
  ready,
  placeFinger,
  fingerDetected,
  sensorStarted,
  recording,
  result,
  aborted,
  info,
  error,
}

/// One parsed firmware line.
class VitalsParseResult {
  const VitalsParseResult({
    required this.kind,
    this.status,
    this.sensor,
    this.abortReason,
    this.elapsedSeconds,
    this.remSeconds,
    this.heartRate,
    this.spo2,
    this.finalHeartRate,
    this.finalSpO2,
    this.ok = false,
    this.temperatureC,
    this.temperatureF,
    this.ambientTempF,
    this.canCaptureTemp = false,
    this.finger,
    this.fingerAbsent = false,
    this.max30102Ok,
    this.mlx90614Ok,
    this.infoMessage,
    this.errorMessage,
    this.rawLine,
    this.recognized = true,
  });

  final VitalsMessageKind kind;
  final String? status;
  final String? sensor;
  final String? abortReason;
  final int? elapsedSeconds;
  final double? remSeconds;
  final double? heartRate;
  final double? spo2;
  final double? finalHeartRate;
  final double? finalSpO2;
  final bool ok;
  final double? temperatureC;
  final double? temperatureF;
  final double? ambientTempF;
  final bool canCaptureTemp;
  final bool? finger;
  final bool fingerAbsent;
  final bool? max30102Ok;
  final bool? mlx90614Ok;
  final String? infoMessage;
  final String? errorMessage;
  final String? rawLine;
  final bool recognized;

  bool get isReady => kind == VitalsMessageKind.ready;
  bool get isPlaceFinger => kind == VitalsMessageKind.placeFinger;
  bool get isFingerDetected => kind == VitalsMessageKind.fingerDetected;
  bool get isSensorStarted => kind == VitalsMessageKind.sensorStarted;
  bool get isRecording => kind == VitalsMessageKind.recording;
  bool get isResult => kind == VitalsMessageKind.result;
  bool get isAborted => kind == VitalsMessageKind.aborted;
  bool get isInfo => kind == VitalsMessageKind.info;
  bool get isError => kind == VitalsMessageKind.error;

  bool get isMaxRecording => isRecording && sensor == 'max30102';
  bool get isTempRecording => isRecording && sensor == 'mlx90614';
  bool get isFingerRemovedAbort =>
      isAborted && abortReason == 'finger_removed';

  /// Convenience alias used by older callers / tests.
  double? get temperature => temperatureC;
}
