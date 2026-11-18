import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/network/service_enablement.dart';
import 'package:skp_kiosk/features/home/presentation/under_maintenance_page.dart';

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
  group('isServiceEnablementError', () {
    test('detects service_disabled and service_unavailable', () {
      expect(
        isServiceEnablementError(
          ApiException(code: 'service_disabled', message: 'off'),
        ),
        isTrue,
      );
      expect(
        isServiceEnablementError(
          ApiException(code: 'service_unavailable', message: 'gone'),
        ),
        isTrue,
      );
      expect(
        isServiceEnablementError(
          ApiException(code: 'not_found', message: 'missing'),
        ),
        isFalse,
      );
      expect(isServiceEnablementError(Exception('nope')), isFalse);
    });
  });

  testWidgets('reportServiceEnablementBlocked opens Under maintenance only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthProvider.overrideWith(_AuthedDeviceAuth.new),
        ],
        child: MaterialApp(
          navigatorKey: kioskNavigatorKey,
          home: const Scaffold(body: Text('Home grid')),
        ),
      ),
    );

    final handled = reportServiceEnablementBlocked(
      ApiException(
        code: 'service_disabled',
        message: 'Service local_services is disabled for this device',
      ),
      serviceTitle: 'Find Services',
    );
    expect(handled, isTrue);
    await tester.pumpAndSettle();

    expect(find.byType(UnderMaintenancePage), findsOneWidget);
    expect(find.text('Under maintenance'), findsWidgets);
    expect(
      find.text('Find Services is temporarily unavailable on this kiosk.'),
      findsOneWidget,
    );
    expect(find.text('This service is not available on this kiosk.'), findsNothing);
    expect(find.textContaining('disabled for this device'), findsNothing);
  });
}
