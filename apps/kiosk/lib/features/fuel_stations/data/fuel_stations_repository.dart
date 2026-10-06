import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/fuel_stations/domain/fuel_station.dart';

class FuelStationsRepository {
  FuelStationsRepository(this._api);

  final ApiClient _api;

  Future<List<FuelStation>> list({required FuelKind kind}) async {
    final result = await _api.get('/fuel-stations?kind=${kind.name}&limit=30');
    final items = result['items'];
    if (items is! List) {
      return const [];
    }
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) FuelStation.fromJson(item),
    ];
  }
}
