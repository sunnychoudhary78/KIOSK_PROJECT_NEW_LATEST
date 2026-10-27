import 'dart:typed_data';

import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/quick_print/domain/quick_print_session.dart';
import 'package:skp_kiosk/services/printer/print_status_body.dart';

class QuickPrintRepository {
  QuickPrintRepository(this._api);

  final ApiClient _api;

  Future<QuickPrintSession> createSession() async {
    final result = await _api.post('/quick-print/sessions');
    return _sessionFrom(result, publicUrl: result['publicUrl'] as String? ?? '');
  }

  Future<QuickPrintSession> getSession(String sessionId, {String? publicUrl}) async {
    final result = await _api.get('/quick-print/sessions/$sessionId');
    return _sessionFrom(result, publicUrl: publicUrl ?? '');
  }

  Future<QuickPrintClaim> claim(String sessionId) async {
    final result = await _api.post('/quick-print/sessions/$sessionId/claim');
    final printJob = result['printJob'] as Map<String, dynamic>;
    final docs = (result['documents'] as List<dynamic>? ?? [])
        .map(
          (raw) => QuickPrintDocumentRef(
            id: raw['id'] as String,
            fileName: raw['fileName'] as String,
            pageCount: raw['pageCount'] as int? ?? 1,
            contentPath: raw['contentPath'] as String,
          ),
        )
        .toList();
    return QuickPrintClaim(
      sessionId: result['sessionId'] as String,
      printJobId: printJob['id'] as String,
      title: printJob['title'] as String? ?? 'Quick Print',
      printColorMode: result['printColorMode'] == 'color' ? 'color' : 'bw',
      documents: docs,
    );
  }

  Future<void> cancel(String sessionId) async {
    await _api.post('/quick-print/sessions/$sessionId/cancel');
  }

  Future<Uint8List> downloadDocument(String contentPath) {
    return _api.getBytes(contentPath);
  }

  Future<void> reportStatus({
    required String jobId,
    required String status,
    String? errorMessage,
    int? pagesReported,
    String? spoolerJobId,
    int? pageCounterBefore,
    int? pageCounterAfter,
    String? reconcileStatus,
    String? reconcileDetail,
    bool? needsAdminReview,
    bool? holdForRetry,
  }) async {
    await _api.patch(
      '/print-jobs/$jobId/status',
      body: printStatusBody(
        status: status,
        errorMessage: errorMessage,
        pagesReported: pagesReported,
        spoolerJobId: spoolerJobId,
        pageCounterBefore: pageCounterBefore,
        pageCounterAfter: pageCounterAfter,
        reconcileStatus: reconcileStatus,
        reconcileDetail: reconcileDetail,
        needsAdminReview: needsAdminReview,
        holdForRetry: holdForRetry,
      ),
    );
  }

  QuickPrintSession _sessionFrom(Map<String, dynamic> json, {required String publicUrl}) {
    return QuickPrintSession(
      id: json['id'] as String,
      status: json['status'] as String,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '')?.toLocal() ??
          DateTime.now().add(const Duration(minutes: 10)),
      publicUrl: publicUrl,
      deviceName: json['deviceName'] as String?,
      documentLabel: json['documentLabel'] as String? ?? '',
      pageCount: json['pageCount'] as int? ?? 0,
    );
  }
}
