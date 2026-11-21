import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/support/domain/support_category.dart';

class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> submit({
    required SupportCategory category,
    required String message,
    required String phone,
  }) {
    return _api.post('/support-queries/kiosk', body: {
      'category': category.apiValue,
      'message': message,
      'phone': phone.trim(),
    });
  }
}
