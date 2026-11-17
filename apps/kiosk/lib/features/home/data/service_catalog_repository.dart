import 'package:skp_kiosk/core/network/api_client.dart';

class ServiceCatalogRepository {
  ServiceCatalogRepository(this._api);

  final ApiClient _api;

  /// Returns a map of platform service code → enabled for this device JWT.
  Future<Map<String, bool>> fetchEnabledByCode() async {
    final json = await _api.get('/services');
    final items = json['items'] as List<dynamic>? ?? const [];
    final map = <String, bool>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      final code = raw['code']?.toString();
      if (code == null || code.isEmpty) continue;
      map[code] = raw['enabled'] == true;
    }
    return map;
  }
}
