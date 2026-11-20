import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_contact.dart';

class AstrologyContactsRepository {
  AstrologyContactsRepository(this._api);

  final ApiClient _api;

  Future<List<AstrologyContact>> list({required AstrologyContactKind kind}) async {
    final result = await _api.get('/astrology-contacts?kind=${kind.name}');
    final items = result['items'];
    if (items is! List) {
      return const [];
    }
    return [
      for (final item in items)
        if (item is Map)
          AstrologyContact.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}
