import 'package:skp_admin/core/network/api_client.dart';
import 'package:skp_admin/features/fleet/data/device.dart';

class DevicesRepository {
  DevicesRepository(this._api);

  final ApiClient _api;

  Future<List<KioskDevice>> list() async {
    final body = await _api.get('/devices');
    return _items(body);
  }

  Future<KioskDevice> setStatus(String deviceId, String status) async {
    final body = await _api.patch('/devices/$deviceId/status', body: {'status': status});
    return KioskDevice.fromJson(body);
  }

  Future<KioskDevice> setTray(
    String deviceId, {
    required String mode,
    required int pages,
  }) async {
    final body = await _api.patch(
      '/devices/$deviceId/printer-tray',
      body: {'mode': mode, 'pages': pages},
    );
    return KioskDevice.fromJson(body);
  }

  Future<KioskDevice> enablePrinting(String deviceId) async {
    final body = await _api.post('/devices/$deviceId/printing-enable');
    return KioskDevice.fromJson(body);
  }

  Future<String> requestPrinterRefresh(String deviceId) async {
    final body = await _api.post('/devices/$deviceId/printer-refresh');
    final requestedAt = body['requestedAt'];
    if (requestedAt is! String || requestedAt.isEmpty) {
      throw const ApiException('The printer refresh did not start');
    }
    return requestedAt;
  }

  List<KioskDevice> _items(Map<String, dynamic> body) {
    final raw = body['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => KioskDevice.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
