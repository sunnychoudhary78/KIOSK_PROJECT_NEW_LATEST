import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/weather/domain/air_quality_detail.dart';

void main() {
  test('AirQualityDetail.fromJson maps API fields', () {
    final detail = AirQualityDetail.fromJson({
      'aqi': 285,
      'aqiLabel': 'Poor',
      'dominantPollutant': 'PM2.5',
      'color': {'r': 204, 'g': 51, 'b': 51},
      'pollutants': [
        {
          'code': 'pm25',
          'displayName': 'PM2.5',
          'concentration': {
            'value': 142.5,
            'units': 'MICROGRAMS_PER_CUBIC_METER',
          },
        },
        {
          'code': 'pm10',
          'displayName': 'PM10',
          'concentration': {
            'value': 210,
            'units': 'MICROGRAMS_PER_CUBIC_METER',
          },
        },
      ],
      'healthRecommendations': {
        'generalPopulation': 'Limit prolonged outdoor exposure.',
        'elderly': 'Avoid outdoor activity.',
        'children': 'Reduce outdoor play.',
      },
      'updatedAt': '2026-11-16T10:00:00Z',
    });

    expect(detail.aqi, 285);
    expect(detail.aqiLabel, 'Poor');
    expect(detail.dominantPollutant, 'PM2.5');
    expect(detail.color?.r, 204);
    expect(detail.color?.g, 51);
    expect(detail.color?.b, 51);
    expect(detail.pollutants, hasLength(2));
    expect(detail.pollutantByCode('pm25')?.concentration?.value, 142.5);
    expect(detail.pollutantByCode('pm10')?.displayName, 'PM10');
    expect(
      detail.healthRecommendations?.generalPopulation,
      'Limit prolonged outdoor exposure.',
    );
    expect(detail.healthRecommendations?.sensitiveGroups, hasLength(2));
    expect(detail.updatedAt, '2026-11-16T10:00:00Z');
    expect(detail.hasDisplayableData, isTrue);
  });

  test('AirQualityHistory.fromJson maps points', () {
    final history = AirQualityHistory.fromJson({
      'points': [
        {
          'dateTime': '2026-11-16T10:00:00Z',
          'aqi': 180,
          'aqiLabel': 'Moderate',
        },
        {
          'dateTime': '2026-11-16T11:00:00Z',
          'aqi': 200,
          'aqiLabel': 'Moderate',
        },
      ],
    });

    expect(history.points, hasLength(2));
    expect(history.points.first.aqi, 180);
    expect(history.points.last.dateTime, '2026-11-16T11:00:00Z');
  });

  test('empty detail has no displayable data', () {
    expect(const AirQualityDetail().hasDisplayableData, isFalse);
  });
}
