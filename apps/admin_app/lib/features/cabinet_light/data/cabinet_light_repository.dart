import 'package:skp_admin/core/network/api_client.dart';
import 'package:skp_admin/features/cabinet_light/data/cabinet_light.dart';

class CabinetLightRepository {
  CabinetLightRepository(this._api);

  final ApiClient _api;

  Future<CabinetLightConfig> load() async {
    final body = await _api.get('/cabinet-light');
    return CabinetLightConfig.fromJson(body);
  }

  Future<void> save(CabinetLightConfig config) async {
    await _api.put(
      '/platform-settings/cabinet_light_config',
      body: {
        'settingValue': config.toJson(),
        'description': 'Cabinet light on relay 2',
      },
    );
  }
}
