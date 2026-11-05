import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/support/domain/support_category.dart';

class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> submit({
    required SupportCategory category,
    required String message,
    String? phone,
  }) {
    final body = <String, dynamic>{
      'category': category.apiValue,
      'message': message,
    };
    final trimmed = phone?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      body['phone'] = trimmed;
    }
    return _api.post('/support-queries/kiosk', body: body);
  }
}
