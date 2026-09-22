import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:uuid/uuid.dart';

class ApiClient {
  ApiClient({AppConfig? config, http.Client? httpClient})
      : _config = config ?? AppConfig.fromEnvironment(),
        _http = httpClient ?? http.Client();

  final AppConfig _config;
  final http.Client _http;
  String? _accessToken;

  void setAccessToken(String? token) => _accessToken = token;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _http.post(
      Uri.parse('${_config.apiBaseUrl}$path'),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _http.get(
      Uri.parse('${_config.apiBaseUrl}$path'),
      headers: _headers(),
    );
    return _decode(response);
  }

  Future<Uint8List> getBytes(String path) async {
    final response = await _http.get(
      Uri.parse('${_config.apiBaseUrl}${_resolvePath(path)}'),
      headers: _headers(json: false),
    );
    if (response.statusCode >= 400) {
      Map<String, dynamic> payload = <String, dynamic>{};
      try {
        payload = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}
      throw ApiException(
        code: payload['code']?.toString() ?? 'request_failed',
        message: payload['message']?.toString() ?? response.reasonPhrase ?? 'Request failed',
      );
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _http.patch(
      Uri.parse('${_config.apiBaseUrl}$path'),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  /// Avoid `/v1/v1/...` when API returns legacy paths that already include `/v1`.
  String _resolvePath(String path) {
    final base = _config.apiBaseUrl;
    if (path.startsWith('/v1/') && (base.endsWith('/v1') || base.endsWith('/v1/'))) {
      return path.substring(3);
    }
    return path;
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

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required List<int> fileBytes,
    required String fileField,
    required String filename,
    String contentType = 'application/octet-stream',
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_config.apiBaseUrl}$path'),
    );
    request.headers.addAll(_headers(json: false));
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    );
    final streamed = await _http.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 204) {
      return <String, dynamic>{};
    }
    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        code: payload['code']?.toString() ?? 'request_failed',
        message: payload['message']?.toString() ?? response.reasonPhrase ?? 'Request failed',
      );
    }
    return payload;
  }

  /// PUT a local file to a presigned URL. Never attaches the device JWT.
  Future<void> putFileToUrl({
    required String url,
    required File file,
    String contentType = 'video/mp4',
  }) async {
    final length = await file.length();
    final request = http.StreamedRequest('PUT', Uri.parse(url));
    request.headers['Content-Type'] = contentType;
    request.contentLength = length;
    file.openRead().listen(
      request.sink.add,
      onError: request.sink.addError,
      onDone: request.sink.close,
      cancelOnError: true,
    );
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 400) {
      throw ApiException(
        code: 'upload_failed',
        message: response.reasonPhrase ?? 'Upload failed',
      );
    }
  }
}

class ApiException implements Exception {
  ApiException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'ApiException($code): $message';
}
