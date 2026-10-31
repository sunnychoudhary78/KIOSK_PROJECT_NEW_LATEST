import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:skp_admin/core/config/app_config.dart';
import 'package:uuid/uuid.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final Uuid _uuid = const Uuid();
  String? _accessToken;
  void Function()? onUnauthorized;

  void setAccessToken(String? token) => _accessToken = token;

  void close() => _http.close();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _uri(path).replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final response = await _http.get(uri, headers: _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _http.post(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _http.patch(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Uri _uri(String path) {
    final base = AppConfig.current.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Correlation-Id': _uuid.v4(),
    };
    final token = _accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> payload = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      } else if (decoded is Map) {
        payload = Map<String, dynamic>.from(decoded);
      }
    }
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && _accessToken != null) {
        onUnauthorized?.call();
      }
      throw ApiException(
        payload['message'] as String? ?? 'Request failed',
        statusCode: response.statusCode,
        code: payload['code'] as String?,
      );
    }
    return payload;
  }
}
