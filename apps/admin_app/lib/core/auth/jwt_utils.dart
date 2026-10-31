import 'dart:convert';

const jwtExpiryBufferSeconds = 30;

bool isJwtExpired(String token, {int bufferSeconds = jwtExpiryBufferSeconds}) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return true;

    final payload = _payload(token);
    if (payload == null) return true;

    final exp = payload['exp'];
    if (exp is! num) return false;

    final expiresAtMs = exp.toInt() * 1000;
    final bufferMs = bufferSeconds * 1000;
    return DateTime.now().millisecondsSinceEpoch >= expiresAtMs - bufferMs;
  } catch (_) {
    return true;
  }
}

String? roleFromToken(String? token) {
  if (token == null || token.isEmpty) return null;
  final payload = _payload(token);
  final role = payload?['role'];
  return role is String ? role : null;
}

bool staffCanWrite(String? role) => role == 'admin' || role == 'operator';

Map<String, dynamic>? _payload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    final normalized = base64Url.normalize(parts[1]);
    final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  } catch (_) {
    return null;
  }
}
