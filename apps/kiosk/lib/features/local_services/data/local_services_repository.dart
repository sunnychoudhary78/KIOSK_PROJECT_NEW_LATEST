import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/local_services/domain/local_service.dart';

class LocalServicesRepository {
  LocalServicesRepository(this._api);

  final ApiClient _api;

  Future<List<LocalServiceCategory>> list() async {
    final result = await _api.get('/local-services');
    final items = result['categories'];
    if (items is! List) {
      return const [];
    }
    return [
      for (final item in items)
        if (item is Map) LocalServiceCategory.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}
