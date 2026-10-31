import 'package:skp_admin/core/network/api_client.dart';
import 'package:skp_admin/features/print_jobs/data/print_job.dart';

class PrintJobsRepository {
  PrintJobsRepository(this._api);

  final ApiClient _api;

  Future<List<PrintJob>> list() async {
    final body = await _api.get('/print-jobs');
    final raw = body['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => PrintJob.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
