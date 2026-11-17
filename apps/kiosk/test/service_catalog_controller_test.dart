import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/home/application/service_catalog_controller.dart';
import 'package:skp_kiosk/features/home/domain/kiosk_home_service.dart';

class _AuthedDeviceAuth extends DeviceAuthNotifier {
  @override
  DeviceAuthState build() {
    return const DeviceAuthState(
      accessToken: 'token',
      deviceId: 'device-1',
      deviceName: 'Lobby Kiosk',
      provisioned: true,
    );
  }
}

void main() {
  const config = AppConfig(apiBaseUrl: 'http://example.test/v1', environment: 'test');

  test('refresh loads enablement map and gates home services', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/services');
      return http.Response(
        jsonEncode({
          'items': [
            {'code': 'otp_print', 'name': 'OTP', 'enabled': true},
            {'code': 'quick_print', 'name': 'Quick', 'enabled': true},
            {'code': 'digilocker_print', 'name': 'Digi', 'enabled': true},
            {'code': 'well_being', 'name': 'Well', 'enabled': false},
            {'code': 'astrology', 'name': 'Astro', 'enabled': true},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final container = ProviderContainer(
      overrides: [
        deviceAuthProvider.overrideWith(_AuthedDeviceAuth.new),
        apiClientProvider.overrideWithValue(
          ApiClient(config: config, httpClient: client),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(serviceCatalogControllerProvider.notifier);
    await notifier.refresh();

    final state = container.read(serviceCatalogControllerProvider);
    expect(state.loadedOnce, isTrue);
    expect(state.isHomeServiceEnabled(KioskHomeService.printDocuments), isTrue);
    expect(state.isHomeServiceEnabled(KioskHomeService.wellBeing), isFalse);
    expect(state.isHomeServiceEnabled(KioskHomeService.astrology), isTrue);
    // Missing phone_charging after a successful fetch ⇒ disabled.
    expect(state.isHomeServiceEnabled(KioskHomeService.phoneCharging), isFalse);
  });

  test('soft-fail keeps last known map', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      if (calls == 1) {
        return http.Response(
          jsonEncode({
            'items': [
              {'code': 'well_being', 'name': 'Well', 'enabled': false},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('boom', 500);
    });

    final container = ProviderContainer(
      overrides: [
        deviceAuthProvider.overrideWith(_AuthedDeviceAuth.new),
        apiClientProvider.overrideWithValue(
          ApiClient(config: config, httpClient: client),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(serviceCatalogControllerProvider.notifier);
    await notifier.refresh();
    expect(
      container.read(serviceCatalogControllerProvider).isHomeServiceEnabled(
            KioskHomeService.wellBeing,
          ),
      isFalse,
    );

    await notifier.refresh();
    expect(
      container
          .read(serviceCatalogControllerProvider)
          .isHomeServiceEnabled(KioskHomeService.wellBeing),
      isFalse,
    );
    expect(container.read(serviceCatalogControllerProvider).byCode?['well_being'], isFalse);
  });
}
