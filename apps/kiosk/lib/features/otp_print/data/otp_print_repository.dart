import 'dart:typed_data';

import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/otp_print/domain/otp_redeem_result.dart';

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
    final printJob = result['printJob'] as Map<String, dynamic>;
    final docs = (result['documents'] as List<dynamic>? ?? [])
        .map(
          (raw) => OtpDocumentRef(
            id: raw['id'] as String,
            fileName: raw['fileName'] as String,
            pageCount: raw['pageCount'] as int? ?? 1,
            contentPath: raw['contentPath'] as String,
          ),
        )
        .toList();
    return OtpRedeemResult(
      challengeId: result['challengeId'] as String,
      printJobId: printJob['id'] as String,
      title: printJob['title'] as String,
      payloadUrl: printJob['payloadUrl'] as String?,
      printColorMode: printJob['printColorMode'] == 'color' ? 'color' : 'bw',
      documents: docs,
    );
  }

  Future<Uint8List> downloadDocument(String contentPath) {
    return _api.getBytes(contentPath);
  }

  Future<void> reportStatus({
    required String jobId,
    required String status,
    String? errorMessage,
  }) async {
    await _api.patch(
      '/print-jobs/$jobId/status',
      body: {
        'status': status,
        'errorMessage': ?errorMessage,
      },
    );
  }
}
