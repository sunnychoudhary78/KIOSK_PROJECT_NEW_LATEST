import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/theme/app_theme.dart';
import 'package:skp_kiosk/features/device/data/device_credential_store.dart';
import 'package:skp_kiosk/features/support/application/support_controller.dart';
import 'package:skp_kiosk/core/ui/kiosk_text_caret.dart';
import 'package:skp_kiosk/features/support/presentation/support_page.dart';

class _EmptyCredentialStore extends DeviceCredentialStore {
  @override
  Future<DeviceCredentials?> load() async => null;
}

class _WarningSupport extends SupportController {
  @override
  SupportFormState build() {
    return const SupportFormState(
      message: 'Hello',
      error: 'Please wait a few minutes before sending another message.',
    );
  }
}

void main() {
  testWidgets('support form fits when a warning is showing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceCredentialStoreProvider.overrideWithValue(_EmptyCredentialStore()),
          supportControllerProvider.overrideWith(_WarningSupport.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SupportPage(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Please wait a few minutes before sending another message.'),
      findsOneWidget,
    );
    expect(find.byType(KioskTextCaret), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
