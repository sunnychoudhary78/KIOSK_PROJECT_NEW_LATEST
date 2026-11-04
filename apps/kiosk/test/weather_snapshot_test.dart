import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/weather/domain/weather_snapshot.dart';

void main() {
  test('WeatherSnapshot.fromJson maps API fields', () {
    final snap = WeatherSnapshot.fromJson({
      'temperatureC': 32.1,
      'feelsLikeC': 36.4,
      'humidityPct': 48,
      'weatherCode': 2,
      'weatherLabel': 'Partly cloudy',
      'windKmh': 12.4,
      'uvIndex': 7.2,
      'aqi': 142,
      'aqiLabel': 'Moderate',
      'dominantPollutant': 'PM2.5',
    });

    expect(snap.temperatureC, 32.1);
    expect(snap.feelsLikeC, 36.4);
    expect(snap.humidityPct, 48);
    expect(snap.weatherCode, 2);
    expect(snap.weatherLabel, 'Partly cloudy');
    expect(snap.windKmh, 12.4);
    expect(snap.uvIndex, 7.2);
    expect(snap.aqi, 142);
    expect(snap.aqiLabel, 'Moderate');
    expect(snap.dominantPollutant, 'PM2.5');
    expect(snap.hasDisplayableData, isTrue);
  });

  test('hasDisplayableData is false when empty', () {
    expect(const WeatherSnapshot().hasDisplayableData, isFalse);
  });
}
