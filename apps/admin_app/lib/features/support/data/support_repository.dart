import 'package:skp_admin/core/network/api_client.dart';
import 'package:skp_admin/features/support/data/support_query.dart';

class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  Future<SupportList> list({String? status, String? source}) async {
    final query = <String, String>{};
    if (status != null && status != 'all') query['status'] = status;
    if (source != null && source != 'all') query['source'] = source;
    final body = await _api.get('/support-queries', query: query);
    final raw = body['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => SupportQuery.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : const <SupportQuery>[];
    final openCount = body['openCount'];
    return SupportList(
      items: items,
      openCount: openCount is num ? openCount.toInt() : 0,
    );
  }

  Future<SupportQuery> resolve(String queryId, String resolution) async {
    final body = await _api.post(
      '/support-queries/$queryId/resolve',
      body: {'resolution': resolution},
    );
    return SupportQuery.fromJson(body);
  }

  Future<SupportQuery> resendOtp(String queryId) async {
    final body = await _api.post('/support-queries/$queryId/resend-otp');
    return SupportQuery.fromJson(body);
  }
}
