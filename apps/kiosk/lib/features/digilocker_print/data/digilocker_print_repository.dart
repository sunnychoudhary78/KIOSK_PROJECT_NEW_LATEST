import 'dart:typed_data';

import 'package:skp_kiosk/core/network/api_client.dart';

class DigilockerSession {
  const DigilockerSession({
    required this.id,
    required this.status,
    required this.authorizationUrl,
    this.expiresAt,
    this.authorizedAt,
  });

  final String id;
  final String status;
  final String authorizationUrl;
  final String? expiresAt;
  final String? authorizedAt;

  factory DigilockerSession.fromJson(Map<String, dynamic> json) {
    return DigilockerSession(
      id: json['id'] as String,
      status: json['status'] as String,
      authorizationUrl: json['authorizationUrl'] as String,
      expiresAt: json['expiresAt'] as String?,
      authorizedAt: json['authorizedAt'] as String?,
    );
  }
}

class DigilockerDocument {
  const DigilockerDocument({
    required this.id,
    required this.name,
    required this.issuer,
    this.description,
    this.doctype,
    this.source,
  });

  final String id;
  final String name;
  final String issuer;
  final String? description;
  final String? doctype;
  final String? source;

  String get subtitle {
    final parts = <String>[];
    if (description != null && description!.trim().isNotEmpty) {
      parts.add(description!.trim());
    }
    if (issuer.trim().isNotEmpty) {
      parts.add(issuer.trim());
    }
    if (source != null && source!.trim().isNotEmpty) {
      final label = switch (source) {
        'uploaded' => 'Uploaded',
        'eaadhaar' => 'e-Aadhaar',
        _ => 'Issued',
      };
      parts.add(label);
    }
    return parts.join(' · ');
  }
}

class DigilockerPrintRepository {
  DigilockerPrintRepository(this._api);

  final ApiClient _api;

  Future<DigilockerSession> startSession() async {
    final result = await _api.post('/digilocker/sessions', body: {});
    return DigilockerSession.fromJson(result);
  }

  Future<DigilockerSession> getSession(String sessionId) async {
    final result = await _api.get('/digilocker/sessions/$sessionId');
    return DigilockerSession.fromJson(result);
  }

  Future<List<DigilockerDocument>> listDocuments(String sessionId) async {
    final result = await _api.get('/digilocker/sessions/$sessionId/documents');
    final items = (result['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return items
        .map(
          (item) => DigilockerDocument(
            id: item['id'] as String,
            name: item['name'] as String,
            issuer: item['issuer'] as String? ?? '',
            description: item['description'] as String?,
            doctype: item['doctype'] as String?,
            source: item['source'] as String?,
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> printDocument({
    required String sessionId,
    required String documentId,
    String? title,
  }) async {
    return _api.post(
      '/digilocker/sessions/$sessionId/print',
      body: {
        'documentId': documentId,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      },
    );
  }

  Future<Uint8List> downloadPrintContent(String jobId) async {
    return _api.getBytes('/print-jobs/$jobId/content');
  }

  Future<void> reportStatus({
    required String jobId,
    required String status,
  }) async {
    await _api.patch(
      '/print-jobs/$jobId/status',
      body: {'status': status},
    );
  }
}
