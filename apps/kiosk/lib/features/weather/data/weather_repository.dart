import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/weather/domain/air_quality_detail.dart';
import 'package:skp_kiosk/features/weather/domain/weather_snapshot.dart';

class WeatherRepository {
  WeatherRepository(this._api);

  final ApiClient _api;

  Future<WeatherSnapshot> fetch() async {
    final result = await _api.get('/weather');
    return WeatherSnapshot.fromJson(result);
  }

  Future<AirQualityDetail> fetchAirQualityDetail() async {
    final result = await _api.get('/weather/air-quality');
    return AirQualityDetail.fromJson(result);
  }

  Future<AirQualityHistory> fetchAirQualityHistory({int hours = 24}) async {
    final result = await _api.get('/weather/air-quality/history?hours=$hours');
    return AirQualityHistory.fromJson(result);
  }
}
