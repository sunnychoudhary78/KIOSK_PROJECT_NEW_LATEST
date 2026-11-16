import 'dart:typed_data';

import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/otp_print/domain/otp_redeem_result.dart';
import 'package:skp_kiosk/services/printer/print_status_body.dart';

class OtpPrintRepository {
  OtpPrintRepository(this._api);

  final ApiClient _api;

  Future<OtpRedeemResult> redeem(String code) async {
    final result = await _api.post(
      '/otp-challenges/redeem',
      body: {
        'code': code,
        'idempotencyKey': 'kiosk-redeem-$code-${DateTime.now().millisecondsSinceEpoch}',
      },
    );
    final docs = (result['documents'] as List<dynamic>? ?? [])
        .map(
          (raw) => OtpDocumentRef(
            id: raw['id'] as String,
            fileName: raw['fileName'] as String,
            pageCount: raw['pageCount'] as int? ?? 1,
            contentPath: raw['contentPath'] as String,
            printJobId: raw['printJobId'] as String?,
            printed: raw['printed'] == true,
          ),
        )
        .toList();
    return OtpRedeemResult(
      challengeId: result['challengeId'] as String,
      title: result['title'] as String? ?? 'Your documents',
      printColorMode: result['printColorMode'] == 'color' ? 'color' : 'bw',
      documents: docs,
    );
  }

  Future<Map<String, dynamic>> createDocumentPrintJob({
    required String challengeId,
    required String documentId,
  }) {
    return _api.post(
      '/otp-challenges/$challengeId/documents/$documentId/print-jobs',
    );
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
}
