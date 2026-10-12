class WeatherSnapshot {
  const WeatherSnapshot({
    this.temperatureC,
    this.humidityPct,
    this.weatherCode,
    this.weatherLabel,
    this.windKmh,
    this.uvIndex,
    this.aqi,
    this.aqiLabel,
  });

  final double? temperatureC;
  final int? humidityPct;
  final int? weatherCode;
  final String? weatherLabel;
  final double? windKmh;
  final double? uvIndex;
  final int? aqi;
  final String? aqiLabel;

  bool get hasDisplayableData =>
      temperatureC != null ||
      humidityPct != null ||
      weatherLabel != null ||
      windKmh != null ||
      uvIndex != null ||
      aqi != null;

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      temperatureC: _asDouble(json['temperatureC']),
      humidityPct: _asInt(json['humidityPct']),
      weatherCode: _asInt(json['weatherCode']),
      weatherLabel: json['weatherLabel'] as String?,
      windKmh: _asDouble(json['windKmh']),
      uvIndex: _asDouble(json['uvIndex']),
      aqi: _asInt(json['aqi']),
      aqiLabel: json['aqiLabel'] as String?,
    );
  }

  static double? _asDouble(Object? raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }
    return null;
  }

  static int? _asInt(Object? raw) {
    if (raw is num) {
      return raw.round();
    }
    if (raw is String) {
      return int.tryParse(raw) ?? double.tryParse(raw)?.round();
    }
    return null;
  }
}
