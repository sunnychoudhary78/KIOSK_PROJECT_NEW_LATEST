import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skp_mobile/core/auth/jwt_utils.dart';

String _jwt({required int exp}) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final payload = base64Url.encode(utf8.encode('{"exp":$exp}'));
  return '$header.$payload.signature';
}

void main() {
  group('isJwtExpired', () {
    test('returns true for malformed token', () {
      expect(isJwtExpired('not-a-jwt'), isTrue);
    });

    test('returns false for valid future exp', () {
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      expect(isJwtExpired(_jwt(exp: exp)), isFalse);
    });

    test('returns true for past exp', () {
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
      expect(isJwtExpired(_jwt(exp: exp)), isTrue);
    });

    test('returns true when within expiry buffer', () {
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10;
      expect(isJwtExpired(_jwt(exp: exp)), isTrue);
    });
  });
}
