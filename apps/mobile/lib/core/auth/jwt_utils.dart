import 'dart:convert';

/// Seconds before JWT expiry to treat the token as expired (clock skew buffer).
const jwtExpiryBufferSeconds = 30;

/// Returns true when the JWT is missing, malformed, or past its `exp` claim.
bool isJwtExpired(String token, {int bufferSeconds = jwtExpiryBufferSeconds}) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return true;

    final normalized = base64Url.normalize(parts[1]);
    final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    if (payload is! Map<String, dynamic>) return true;

    final exp = payload['exp'];
    if (exp is! num) return false;

    final expiresAtMs = exp.toInt() * 1000;
    final bufferMs = bufferSeconds * 1000;
    return DateTime.now().millisecondsSinceEpoch >= expiresAtMs - bufferMs;
  } catch (_) {
    return true;
  }
}
