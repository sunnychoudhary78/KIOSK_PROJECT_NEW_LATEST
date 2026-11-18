import 'package:skp_kiosk/core/network/api_client.dart';

class ServiceRatingsRepository {
  ServiceRatingsRepository(this._api);

  final ApiClient _api;

  Future<void> reportRatings(List<Map<String, dynamic>> ratings) async {
    if (ratings.isEmpty) {
      return;
    }
    await _api.post('/analytics/service-ratings', body: {'ratings': ratings});
  }
}
