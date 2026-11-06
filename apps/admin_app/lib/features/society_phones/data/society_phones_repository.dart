import 'package:skp_admin/core/network/api_client.dart';
import 'package:skp_admin/features/society_phones/data/society_phone.dart';

class SocietyPhonesRepository {
  SocietyPhonesRepository(this._api);

  final ApiClient _api;

  Future<SocietyQuota> loadQuota() async {
    final body = await _api.get('/platform-settings');
    final raw = body['items'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        if (item['settingKey'] != 'society_free_quota_config') continue;
        final value = item['settingValue'];
        if (value is Map) {
          return SocietyQuota.fromJson(Map<String, dynamic>.from(value));
        }
      }
    }
    return SocietyQuota.defaults;
  }

  Future<void> saveQuota(SocietyQuota quota) async {
    await _api.put(
      '/platform-settings/society_free_quota_config',
      body: {'settingValue': quota.toJson()},
    );
  }

  Future<SocietyPhoneList> list({String? query}) async {
    final q = query?.trim() ?? '';
    final body = await _api.get(
      '/society-phones',
      query: q.isEmpty ? null : {'q': q},
    );
    final raw = body['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => SocietyPhone.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.id.isNotEmpty)
            .toList()
        : const <SocietyPhone>[];
    final total = body['total'];
    return SocietyPhoneList(
      total: total is num ? total.toInt() : items.length,
      items: items,
    );
  }

  Future<void> add(String phone) async {
    await _api.post('/society-phones', body: {'phone': phone.trim()});
  }

  Future<void> remove(String id) async {
    await _api.delete('/society-phones/$id');
  }
}
