import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';

void main() {
  test('uses a readable API message and never prefixes ApiException', () {
    final message = userFacingError(
      ApiException(code: 'otp_invalid', message: 'Invalid or already used OTP'),
    );
    expect(message, 'Invalid or already used OTP');
    expect(message, isNot(contains('ApiException')));
  });

  test('maps known API codes when the payload message is technical', () {
    expect(
      userFacingError(ApiException(code: 'device_inactive', message: 'DEVICE_INACTIVE')),
      'This kiosk has been stopped.',
    );
  });

  test('maps network failures', () {
    expect(
      userFacingError(const SocketException('Failed host lookup')),
      "Can't reach the server. Check the connection and try again.",
    );
    expect(
      userFacingError(TimeoutException('timed out')),
      "Can't reach the server. Check the connection and try again.",
    );
  });

  test('falls back for unknown errors', () {
    expect(userFacingError(Exception('boom')), 'Something went wrong. Please try again.');
  });
}
