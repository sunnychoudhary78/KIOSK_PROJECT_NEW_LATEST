import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:skp_mobile/core/config/app_config.dart';
import 'package:uuid/uuid.dart';

class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  String? _accessToken;

  void setAccessToken(String? token) => _accessToken = token;

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final response = await _http.post(
      Uri.parse('${AppConfig.current.apiBaseUrl}$path'),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String>? fields,
    required List<File> files,
    String fileField = 'files',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.current.apiBaseUrl}$path'),
    );
    request.headers.addAll(_headers(json: false));
    if (fields != null) {
      request.fields.addAll(fields);
    }
    for (final file in files) {
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
    }
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{
      'X-Correlation-Id': const Uuid().v4(),
    };
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(payload['message'] ?? 'Request failed');
    }
    return payload;
  }
}
