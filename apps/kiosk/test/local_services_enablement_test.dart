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
import 'package:skp_kiosk/features/home/presentation/under_maintenance_page.dart';
import 'package:skp_kiosk/features/local_services/application/local_services_controller.dart';

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
  testWidgets('local services load opens Under maintenance, not old banner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const config = AppConfig(apiBaseUrl: 'http://example.test/v1', environment: 'test');
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 'service_disabled',
          'message': 'Service local_services is disabled for this device',
        }),
        403,
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: kioskNavigatorKey,
          home: const Scaffold(body: Text('Find Services page')),
        ),
      ),
    );

    await container.read(localServicesControllerProvider.notifier).load();
    await tester.pumpAndSettle();

    expect(find.byType(UnderMaintenancePage), findsOneWidget);
    expect(find.text('This service is not available on this kiosk.'), findsNothing);
    expect(find.textContaining('disabled for this device'), findsNothing);
    expect(container.read(localServicesControllerProvider).error, isNull);
  });
}
