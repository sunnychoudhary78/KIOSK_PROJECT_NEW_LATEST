import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/weather/domain/weather_snapshot.dart';

class WeatherRepository {
  WeatherRepository(this._api);

  final ApiClient _api;

  Future<WeatherSnapshot> fetch() async {
    final result = await _api.get('/weather');
    return WeatherSnapshot.fromJson(result);
  }
}
