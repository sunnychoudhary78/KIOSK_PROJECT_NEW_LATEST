import 'package:skp_kiosk/core/network/api_client.dart';

class ServiceAnalyticsRepository {
  ServiceAnalyticsRepository(this._api);

  final ApiClient _api;

  Future<void> reportEvents(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) {
      return;
    }
    await _api.post('/analytics/service-events', body: {'events': events});
  }
}
