import 'package:skp_kiosk/core/network/api_client.dart';

class PrintJobSupport {
  const PrintJobSupport(this._api);

  final ApiClient _api;

  Future<void> send({
    required String jobId,
    required String message,
    String? name,
    String? phone,
  }) async {
    final body = <String, dynamic>{'message': message};
    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }
    await _api.post('/print-jobs/$jobId/support-query', body: body);
  }
}
