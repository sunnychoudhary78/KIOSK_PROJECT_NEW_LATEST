import 'package:skp_kiosk/core/network/api_client.dart';

class PrintJobSupport {
  const PrintJobSupport(this._api);

  final ApiClient _api;

  Future<void> send({required String jobId, required String message}) async {
    await _api.post(
      '/print-jobs/$jobId/support-query',
      body: {'message': message},
    );
  }
}
