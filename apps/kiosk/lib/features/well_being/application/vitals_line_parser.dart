/// Parser for ESP pulse-oximeter USB Serial firmware lines.
///
/// Expected line (every ~250ms):
/// `RED=… IR=… HR=78|-- SpO2=98|-- validHR=0|1 validSpO2=0|1 validCount=0..3`
///
/// Finger detect matches firmware: `IR > 50000`.
class VitalsLineParser {
  VitalsLineParser({
    this.frameTimeout = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration frameTimeout;
  final DateTime Function() _clock;

  String _buffer = '';
  _PartialFrame? _frame;

  static const double fingerThreshold = 50000;
  static const double signalExcellentIr = 80000;
  static const double minHeartRate = 30;
  static const double maxHeartRate = 200;
  static const double minSpO2 = 70;
  static const double maxSpO2 = 100;

  /// Feed a raw UTF-8 chunk; returns one result per complete sample line.
  List<VitalsParseResult> addChunk(String chunk) {
    if (chunk.isEmpty) {
      return flushTimedOut();
    }

    final results = <VitalsParseResult>[];
    results.addAll(flushTimedOut());
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
        final flushed = _flushFrame();
        if (flushed != null) {
          results.add(flushed);
        }
        continue;
      }
      results.addAll(_ingestLine(line));
    }

    results.addAll(flushTimedOut());
    return results;
  }

  List<VitalsParseResult> flushTimedOut() {
    final frame = _frame;
    if (frame == null || !frame.hasAnyField) {
      return const [];
    }
    if (_clock().difference(frame.startedAt) < frameTimeout) {
      return const [];
    }
    final emitted = _flushFrame();
    return emitted == null ? const [] : [emitted];
  }

  void reset() {
    _buffer = '';
    _frame = null;
  }

  /// Parse one complete line (tests + direct use).
  VitalsParseResult? parseLine(String line) {
    final results = _ingestLine(line.trim());
    if (results.isNotEmpty) {
      return results.last;
    }
    return _flushFrame();
  }

  List<VitalsParseResult> _ingestLine(String line) {
    final normalized = line.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final lower = normalized.toLowerCase();
    if (_isBootNoise(lower) || _isJunkFragment(normalized)) {
      return const [];
    }

    final fields = _extractFields(normalized);
    if (fields == null) {
      return const [];
    }

    // Full firmware sample: emit immediately (one line = one sample).
    if (fields.isFirmwareSample) {
      final previous = _flushFrame();
      final sample = _resultFromFields(fields);
      if (previous == null) {
        return [sample];
      }
      return [previous, sample];
    }

    // Fragmented USB leftovers — coalesce until timeout / complete.
    _frame ??= _PartialFrame(startedAt: _clock());
    _frame!.merge(fields);
    if (_frame!.isFirmwareSample) {
      final emitted = _flushFrame();
      return emitted == null ? const [] : [emitted];
    }
    return const [];
  }

  VitalsParseResult? _flushFrame() {
    final frame = _frame;
    _frame = null;
    if (frame == null || !frame.hasAnyField) {
      return null;
    }
    return _resultFromFields(frame.toFields());
  }

  VitalsParseResult _resultFromFields(_FieldBag fields) {
    final ir = fields.ir;
    final finger = ir != null ? ir > fingerThreshold : null;

    final validHr = fields.validHr == null ? null : fields.validHr == 1;
    final validSpo2 = fields.validSpo2 == null ? null : fields.validSpo2 == 1;

    double? heartRate;
    if (validHr == true) {
      heartRate = _sanitizeHeartRate(fields.heartRate);
    }

    double? spo2;
    if (validSpo2 == true) {
      spo2 = _sanitizeSpO2(fields.spo2);
    }

    final validCount = fields.validCount?.round().clamp(0, 3);

    return VitalsParseResult(
      heartRate: heartRate,
      spo2: spo2,
      temperature: fields.temperature,
      ir: ir,
      red: fields.red,
      validHr: validHr,
      validSpo2: validSpo2,
      validCount: validCount,
      finger: finger,
      fingerAbsent: finger == false,
    );
  }

  _FieldBag? _extractFields(String normalized) {
    final validHr = _extractKeyedNumber(normalized, const ['validHR']);
    final validSpo2 = _extractKeyedNumber(normalized, const ['validSpO2']);
    final validCount = _extractKeyedNumber(normalized, const ['validCount']);
    final ir = _extractKeyedNumber(normalized, const ['IR']);
    final red = _extractKeyedNumber(normalized, const ['RED']);

    final heartRate = _extractKeyedNumberOrDash(normalized, const ['HR', 'BPM']);
    final spo2 = _extractKeyedNumberOrDash(normalized, const ['SpO2', 'SPO2']);
    final temperature =
        _extractKeyedNumberOrDash(normalized, const ['Temp', 'Temperature', 'TMP']);

    // Also accept simple JSON if firmware is switched later.
    final json = _parseJsonObject(normalized);

    final hr = heartRate ?? json?.heartRate;
    final sp = spo2 ?? json?.spo2;
    final temp = temperature ?? json?.temperature;
    final jIr = ir ?? json?.ir;
    final jRed = red ?? json?.red;
    final jValidHr = validHr ??
        (json?.validHr == null ? null : (json!.validHr! ? 1.0 : 0.0));
    final jValidSpo2 = validSpo2 ??
        (json?.validSpo2 == null ? null : (json!.validSpo2! ? 1.0 : 0.0));
    final jValidCount =
        validCount ?? (json?.validCount == null ? null : json!.validCount!.toDouble());

    if (jValidHr == null &&
        jValidSpo2 == null &&
        jIr == null &&
        jRed == null &&
        hr == null &&
        sp == null &&
        temp == null &&
        jValidCount == null &&
        !normalized.contains('--')) {
      // Line had HR=-- only etc.
      if (!_hasKeyedDash(normalized, const ['HR', 'BPM', 'SpO2', 'SPO2'])) {
        return null;
      }
    }

    return _FieldBag(
      red: jRed,
      ir: jIr,
      heartRate: hr,
      spo2: sp,
      validHr: jValidHr,
      validSpo2: jValidSpo2,
      validCount: jValidCount,
      temperature: temp,
    );
  }

  bool _hasKeyedDash(String line, List<String> keys) {
    for (final key in keys) {
      final pattern = RegExp(
        '(?:^|[^A-Za-z0-9_])$key\\s*[=:]\\s*--',
        caseSensitive: false,
      );
      if (pattern.hasMatch(line)) {
        return true;
      }
    }
    return false;
  }

  double? _sanitizeHeartRate(double? value) {
    if (value == null || value <= 0) {
      return null;
    }
    if (value < minHeartRate || value > maxHeartRate) {
      return null;
    }
    return value;
  }

  double? _sanitizeSpO2(double? value) {
    if (value == null || value <= 0) {
      return null;
    }
    if (value < minSpO2 || value > maxSpO2) {
      return null;
    }
    return value;
  }

  VitalsParseResult? _parseJsonObject(String line) {
    if (!line.startsWith('{') || !line.endsWith('}')) {
      return null;
    }
    final hr = _extractNumber(
      line,
      patterns: [
        RegExp(
          r'"(?:hr|heart_?rate|bpm)"\s*:\s*([0-9]+(?:\.[0-9]+)?)',
          caseSensitive: false,
        ),
      ],
    );
    final spo2 = _extractNumber(
      line,
      patterns: [
        RegExp(
          r'"(?:spo2|sp_?o2)"\s*:\s*([0-9]+(?:\.[0-9]+)?)',
          caseSensitive: false,
        ),
      ],
    );
    final temperature = _extractNumber(
      line,
      patterns: [
        RegExp(
          r'"(?:temp|temperature)"\s*:\s*([0-9]+(?:\.[0-9]+)?)',
          caseSensitive: false,
        ),
      ],
    );
    final ir = _extractNumber(
      line,
      patterns: [RegExp(r'"ir"\s*:\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false)],
    );
    final red = _extractNumber(
      line,
      patterns: [RegExp(r'"red"\s*:\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false)],
    );
    final validCount = _extractNumber(
      line,
      patterns: [
        RegExp(r'"validCount"\s*:\s*([0-9]+)', caseSensitive: false),
      ],
    )?.round();

    bool? validHr;
    final validHrMatch =
        RegExp(r'"validHR"\s*:\s*(true|false|1|0)', caseSensitive: false)
            .firstMatch(line);
    if (validHrMatch != null) {
      final v = validHrMatch.group(1)!.toLowerCase();
      validHr = v == 'true' || v == '1';
    }
    bool? validSpo2;
    final validSpo2Match =
        RegExp(r'"validSpO2"\s*:\s*(true|false|1|0)', caseSensitive: false)
            .firstMatch(line);
    if (validSpo2Match != null) {
      final v = validSpo2Match.group(1)!.toLowerCase();
      validSpo2 = v == 'true' || v == '1';
    }

    if (hr == null &&
        spo2 == null &&
        temperature == null &&
        ir == null &&
        red == null &&
        validCount == null &&
        validHr == null &&
        validSpo2 == null) {
      return null;
    }
    return VitalsParseResult(
      heartRate: hr,
      spo2: spo2,
      temperature: temperature,
      ir: ir,
      red: red,
      validHr: validHr,
      validSpo2: validSpo2,
      validCount: validCount,
      finger: ir == null ? null : ir > fingerThreshold,
    );
  }

  bool _isBootNoise(String lower) {
    const markers = [
      'wifi',
      'wi-fi',
      'ssid',
      'wlan',
      'connecting to',
      'got ip',
      'dhcp',
      'mqtt',
      'http://',
      'https://',
      'kiosk dashboard',
      'max30102 not found',
    ];
    for (final marker in markers) {
      if (lower.contains(marker)) {
        return true;
      }
    }
    if (RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}\b').hasMatch(lower) &&
        !lower.contains('spo2') &&
        !lower.contains('hr=')) {
      return true;
    }
    return false;
  }

  bool _isJunkFragment(String line) {
    if (line.length <= 2 && RegExp(r'^[=:\d.\s-]+$').hasMatch(line)) {
      return true;
    }
    if (RegExp(r'^=\s*[0-9]+(?:\.[0-9]+)?$').hasMatch(line)) {
      return true;
    }
    if (RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(line)) {
      return true;
    }
    return false;
  }

  /// Number value, or null when the firmware prints `--`.
  double? _extractKeyedNumberOrDash(String line, List<String> keys) {
    for (final key in keys) {
      final pattern = RegExp(
        '(?:^|[^A-Za-z0-9_])$key\\s*[=:]\\s*(--|[0-9]+(?:\\.[0-9]+)?)',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(line);
      if (match == null) {
        continue;
      }
      final raw = match.group(1);
      if (raw == null || raw == '--') {
        return null;
      }
      return double.tryParse(raw);
    }
    return null;
  }

  double? _extractKeyedNumber(String line, List<String> keys) {
    for (final key in keys) {
      final pattern = RegExp(
        '(?:^|[^A-Za-z0-9_])$key\\s*[=:]\\s*([0-9]+(?:\\.[0-9]+)?)',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(line);
      if (match == null) {
        continue;
      }
      final raw = match.group(1);
      if (raw == null) {
        continue;
      }
      return double.tryParse(raw);
    }
    return null;
  }

  double? _extractNumber(
    String line, {
    required List<RegExp> patterns,
  }) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match == null) {
        continue;
      }
      final raw = match.group(1);
      if (raw == null) {
        continue;
      }
      return double.tryParse(raw);
    }
    return null;
  }
}

class _FieldBag {
  const _FieldBag({
    this.red,
    this.ir,
    this.heartRate,
    this.spo2,
    this.validHr,
    this.validSpo2,
    this.validCount,
    this.temperature,
  });

  final double? red;
  final double? ir;
  final double? heartRate;
  final double? spo2;
  final double? validHr;
  final double? validSpo2;
  final double? validCount;
  final double? temperature;

  bool get isFirmwareSample =>
      ir != null ||
      (red != null && (validHr != null || validSpo2 != null || validCount != null));
}

class _PartialFrame {
  _PartialFrame({required this.startedAt});

  final DateTime startedAt;
  double? red;
  double? ir;
  double? heartRate;
  double? spo2;
  double? validHr;
  double? validSpo2;
  double? validCount;
  double? temperature;

  bool get hasAnyField =>
      red != null ||
      ir != null ||
      heartRate != null ||
      spo2 != null ||
      validHr != null ||
      validSpo2 != null ||
      validCount != null ||
      temperature != null;

  bool get isFirmwareSample =>
      ir != null ||
      (red != null && (validHr != null || validSpo2 != null || validCount != null));

  void merge(_FieldBag fields) {
    red = fields.red ?? red;
    ir = fields.ir ?? ir;
    heartRate = fields.heartRate ?? heartRate;
    spo2 = fields.spo2 ?? spo2;
    validHr = fields.validHr ?? validHr;
    validSpo2 = fields.validSpo2 ?? validSpo2;
    validCount = fields.validCount ?? validCount;
    temperature = fields.temperature ?? temperature;
  }

  _FieldBag toFields() {
    return _FieldBag(
      red: red,
      ir: ir,
      heartRate: heartRate,
      spo2: spo2,
      validHr: validHr,
      validSpo2: validSpo2,
      validCount: validCount,
      temperature: temperature,
    );
  }
}

/// One firmware sample (or partial coalesce flush).
class VitalsParseResult {
  const VitalsParseResult({
    this.heartRate,
    this.spo2,
    this.temperature,
    this.ir,
    this.red,
    this.validHr,
    this.validSpo2,
    this.validCount,
    this.finger,
    this.fingerAbsent = false,
    this.rawLine,
    this.recognized = true,
  });

  factory VitalsParseResult.unrecognized(String line) {
    return VitalsParseResult(rawLine: line, recognized: false);
  }

  final double? heartRate;
  final double? spo2;
  final double? temperature;
  final double? ir;
  final double? red;
  final bool? validHr;
  final bool? validSpo2;
  final int? validCount;
  final bool? finger;
  final bool fingerAbsent;
  final String? rawLine;
  final bool recognized;

  bool get hasAnyValue =>
      heartRate != null || spo2 != null || temperature != null;

  String get signalQualityLabel {
    final value = ir;
    if (value == null) {
      return 'Unknown';
    }
    if (value > VitalsLineParser.signalExcellentIr) {
      return 'Excellent';
    }
    if (value > VitalsLineParser.fingerThreshold) {
      return 'Fair';
    }
    return 'Poor';
  }
}
