import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/emergency/domain/emergency_contact.dart';

class EmergencyContactsRepository {
  EmergencyContactsRepository(this._api);

  final ApiClient _api;

  Future<List<EmergencyContact>> list() async {
    final result = await _api.get('/emergency-contacts');
    final items = result['items'];
    if (items is! List) {
      return const [];
    }
    return [
      for (final item in items)
        if (item is Map)
          EmergencyContact.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}
