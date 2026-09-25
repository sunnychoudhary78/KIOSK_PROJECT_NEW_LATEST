import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/config/app_config.dart';

void main() {
  group('AppConfig.digilockerCallbackFromApiBase', () {
    test('derives callback from LAN apiBaseUrl', () {
      expect(
        AppConfig.digilockerCallbackFromApiBase('http://192.168.1.30:3000/v1'),
        'http://192.168.1.30:3000/api/v1/auth/digilocker/callback',
      );
    });

    test('derives callback from localhost apiBaseUrl', () {
      expect(
        AppConfig.digilockerCallbackFromApiBase('http://localhost:3000/v1'),
        'http://localhost:3000/api/v1/auth/digilocker/callback',
      );
    });

    test('hideCursor defaults to false for laptop use', () {
      const config = AppConfig(
        apiBaseUrl: 'http://localhost:3000/v1',
        environment: 'local',
      );
      expect(config.hideCursor, isFalse);
    });

    test('digilockerOAuthCallbackUrl on AppConfig instance matches helper', () {
      const config = AppConfig(
        apiBaseUrl: 'http://192.168.1.30:3000/v1',
        environment: 'local',
      );
      expect(
        config.digilockerOAuthCallbackUrl,
        AppConfig.digilockerCallbackFromApiBase(config.apiBaseUrl),
      );
    });
  });
}
