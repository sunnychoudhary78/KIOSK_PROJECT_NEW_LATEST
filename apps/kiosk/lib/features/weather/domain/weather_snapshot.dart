class WeatherSnapshot {
  const WeatherSnapshot({
    this.temperatureC,
    this.feelsLikeC,
    this.humidityPct,
    this.weatherCode,
    this.weatherLabel,
    this.windKmh,
    this.uvIndex,
    this.aqi,
    this.aqiLabel,
    this.dominantPollutant,
  });

  final double? temperatureC;
  final double? feelsLikeC;
  final int? humidityPct;
  final int? weatherCode;
  final String? weatherLabel;
  final double? windKmh;
  final double? uvIndex;
  final int? aqi;
  final String? aqiLabel;
  final String? dominantPollutant;

  bool get hasDisplayableData =>
      temperatureC != null ||
      feelsLikeC != null ||
      humidityPct != null ||
      weatherLabel != null ||
      windKmh != null ||
      uvIndex != null ||
      aqi != null;

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      temperatureC: _asDouble(json['temperatureC']),
      feelsLikeC: _asDouble(json['feelsLikeC']),
      humidityPct: _asInt(json['humidityPct']),
      weatherCode: _asInt(json['weatherCode']),
      weatherLabel: json['weatherLabel'] as String?,
      windKmh: _asDouble(json['windKmh']),
      uvIndex: _asDouble(json['uvIndex']),
      aqi: _asInt(json['aqi']),
      aqiLabel: json['aqiLabel'] as String?,
      dominantPollutant: json['dominantPollutant'] as String?,
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
