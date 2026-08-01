import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/app.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/device/data/device_credential_store.dart';

class _EmptyCredentialStore extends DeviceCredentialStore {
  @override
  Future<DeviceCredentials?> load() async => null;
}

void main() {
  testWidgets('kiosk app boots to activation screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceCredentialStoreProvider.overrideWithValue(_EmptyCredentialStore()),
        ],
        child: const SkpKioskApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Smart Kiosk'), findsOneWidget);
    expect(find.text('Activate this terminal'), findsOneWidget);
  });
}
