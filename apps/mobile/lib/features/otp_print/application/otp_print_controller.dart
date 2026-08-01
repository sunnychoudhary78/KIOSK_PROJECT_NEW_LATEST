import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/core/network/api_client.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';

class OtpDocumentInfo {
  const OtpDocumentInfo({
    required this.id,
    required this.fileName,
    required this.pageCount,
    required this.byteSize,
  });

  final String id;
  final String fileName;
  final int pageCount;
  final int byteSize;
}

class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.code,
    required this.expiresAt,
    required this.documentLabel,
    required this.pageCount,
    required this.documents,
  });

  final String id;
  final String code;
  final String expiresAt;
  final String documentLabel;
  final int pageCount;
  final List<OtpDocumentInfo> documents;
}

class OtpPrintController extends AsyncNotifier<OtpChallenge?> {
  @override
  Future<OtpChallenge?> build() async => null;

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> createChallenge({
    required List<File> files,
    String? documentLabel,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _api.postMultipart(
        '/otp-challenges',
        fields: {
          if (documentLabel != null && documentLabel.isNotEmpty)
            'documentLabel': documentLabel,
        },
        files: files,
        fileField: 'files',
      );
      final docs = (result['documents'] as List<dynamic>? ?? [])
          .map(
            (raw) => OtpDocumentInfo(
              id: raw['id'] as String,
              fileName: raw['fileName'] as String,
              pageCount: raw['pageCount'] as int,
              byteSize: raw['byteSize'] as int,
            ),
          )
          .toList();
      return OtpChallenge(
        id: result['id'] as String,
        code: result['code'] as String,
        expiresAt: result['expiresAt'] as String,
        documentLabel: result['documentLabel'] as String,
        pageCount: result['pageCount'] as int? ?? 1,
        documents: docs,
      );
    });
  }
}

final otpPrintControllerProvider =
    AsyncNotifierProvider<OtpPrintController, OtpChallenge?>(OtpPrintController.new);
