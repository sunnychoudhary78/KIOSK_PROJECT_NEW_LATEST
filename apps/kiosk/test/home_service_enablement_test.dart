import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/device/data/device_credential_store.dart';
import 'package:skp_kiosk/features/home/application/service_catalog_controller.dart';
import 'package:skp_kiosk/features/home/presentation/home_page.dart';
import 'package:skp_kiosk/features/home/presentation/under_maintenance_page.dart';

class MemoryCredentialStore extends DeviceCredentialStore {
  @override
  Future<DeviceCredentials?> load() async => null;

  @override
  Future<void> save(DeviceCredentials credentials) async {}

  @override
  Future<void> clear() async {}
}

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

class _FixedCatalog extends ServiceCatalogController {
  _FixedCatalog(this.map);

  final Map<String, bool> map;

  @override
  ServiceCatalogState build() {
    return ServiceCatalogState(
      byCode: Map<String, bool>.unmodifiable(map),
      loadedOnce: true,
    );
  }

  @override
  Future<void> startWatching() async {}

  @override
  void stopWatching() {}

  @override
  Future<void> refresh() async {
    // Keep the fixed enablement map — do not hit the network.
  }
}

const _config = AppConfig(apiBaseUrl: 'http://example.test/v1', environment: 'test');

ApiClient _quietApi() {
  return ApiClient(
    config: _config,
    httpClient: MockClient((request) async {
      return http.Response(
        jsonEncode({
          'items': <dynamic>[],
          'idle': <dynamic>[],
          'homeBanners': <dynamic>[],
          'homeSideBanners': <dynamic>[],
          'homeCarousels': <dynamic>[],
          'idleTimeoutSeconds': 60,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required Map<String, bool> enablement,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceAuthProvider.overrideWith(_AuthedDeviceAuth.new),
        deviceCredentialStoreProvider.overrideWithValue(MemoryCredentialStore()),
        apiClientProvider.overrideWithValue(_quietApi()),
        serviceCatalogControllerProvider.overrideWith(() => _FixedCatalog(enablement)),
      ],
      child: MaterialApp(
        home: const HomePage(),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('UnderMaintenancePage shows shared copy', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthProvider.overrideWith(_AuthedDeviceAuth.new),
        ],
        child: const MaterialApp(
          home: UnderMaintenancePage(serviceTitle: 'Astrology'),
        ),
      ),
    );
    expect(find.text('Under maintenance'), findsWidgets);
    expect(
      find.text('Astrology is temporarily unavailable on this kiosk.'),
      findsOneWidget,
    );
  });

  testWidgets('disabled service opens under maintenance screen', (tester) async {
    await _pumpHome(
      tester,
      enablement: {
        'otp_print': true,
        'quick_print': true,
        'digilocker_print': true,
        'local_services': true,
        'well_being': false,
        'phone_charging': true,
        'astrology': true,
        'fuel_stations': true,
      },
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Well Being'));
    await tester.pumpAndSettle();

    expect(find.byType(UnderMaintenancePage), findsOneWidget);
    expect(
      find.text('Well Being is temporarily unavailable on this kiosk.'),
      findsOneWidget,
    );
  });

  testWidgets('enabled service leaves the maintenance screen closed', (tester) async {
    await _pumpHome(
      tester,
      enablement: {
        'otp_print': true,
        'quick_print': true,
        'digilocker_print': true,
        'local_services': true,
        'well_being': true,
        'phone_charging': true,
        'astrology': true,
        'fuel_stations': true,
      },
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Print Documents'));
    await tester.pumpAndSettle();

    expect(find.byType(UnderMaintenancePage), findsNothing);
    // Left the home grid for the print chooser.
    expect(find.text('Find Services'), findsNothing);
  });
}
