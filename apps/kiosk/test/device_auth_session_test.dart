import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/device/data/device_credential_store.dart';
import 'package:skp_kiosk/features/home/presentation/home_page.dart';

class MemoryCredentialStore extends DeviceCredentialStore {
  MemoryCredentialStore([this.saved]);

  DeviceCredentials? saved;
  int clearCount = 0;

  @override
  Future<DeviceCredentials?> load() async => saved;

  @override
  Future<void> save(DeviceCredentials credentials) async {
    saved = credentials;
  }

  @override
  Future<void> clear() async {
    clearCount += 1;
    saved = null;
  }
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

class _StoppedDeviceAuth extends DeviceAuthNotifier {
  @override
  DeviceAuthState build() {
    return const DeviceAuthState(
      provisioned: true,
      stopped: true,
      deviceName: 'Lobby Kiosk',
    );
  }
}

void main() {
  const config = AppConfig(apiBaseUrl: 'http://example.test/v1', environment: 'test');

  testWidgets('kiosk catalog has no deactivate or logout control', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthProvider.overrideWith(_AuthedDeviceAuth.new),
          deviceCredentialStoreProvider.overrideWithValue(MemoryCredentialStore()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();
    expect(find.text('Print'), findsOneWidget);
    expect(find.text('OTP Print'), findsNothing);
    expect(find.text('Quick Print'), findsNothing);
    expect(find.text('Deactivate this device'), findsNothing);
    expect(find.text('Activate this terminal'), findsNothing);
  });

  testWidgets('stopped kiosk shows operator message without an activate form', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceAuthProvider.overrideWith(_StoppedDeviceAuth.new),
          deviceCredentialStoreProvider.overrideWithValue(
            MemoryCredentialStore(
              const DeviceCredentials(deviceKey: 'dk_saved', deviceSecret: 'ds_saved'),
            ),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();
    expect(find.text('This kiosk has been stopped'), findsOneWidget);
    expect(find.text('Activate this terminal'), findsNothing);
    expect(find.text('Deactivate this device'), findsNothing);
  });

  test('inactive API response does not wipe saved credentials', () async {
    final store = MemoryCredentialStore(
      const DeviceCredentials(deviceKey: 'dk_saved', deviceSecret: 'ds_saved'),
    );
    final container = ProviderContainer(
      overrides: [
        deviceCredentialStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(
          ApiClient(
            config: config,
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'code': 'device_inactive',
                  'message': 'This kiosk has been stopped',
                }),
                403,
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(deviceAuthProvider, (_, _) {});

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final auth = container.read(deviceAuthProvider);
    expect(auth.stopped, isTrue);
    expect(auth.isAuthenticated, isFalse);
    expect(store.saved?.deviceKey, 'dk_saved');
    expect(store.clearCount, 0);
  });

  test('invalid_credentials clears saved credentials for re-activation', () async {
    final store = MemoryCredentialStore(
      const DeviceCredentials(deviceKey: 'dk_local', deviceSecret: 'ds_local'),
    );
    final container = ProviderContainer(
      overrides: [
        deviceCredentialStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(
          ApiClient(
            config: config,
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'code': 'invalid_credentials',
                  'message': 'Invalid device credentials',
                }),
                401,
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(deviceAuthProvider, (_, _) {});

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final auth = container.read(deviceAuthProvider);
    expect(auth.provisioned, isFalse);
    expect(auth.stopped, isFalse);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.error, 'Invalid device credentials');
    expect(store.saved, isNull);
    expect(store.clearCount, 1);
  });

  test('hanging token request clears loading after timeout', () {
    fakeAsync((async) {
      final store = MemoryCredentialStore();
      final container = ProviderContainer(
        overrides: [
          deviceCredentialStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWithValue(
            ApiClient(
              config: config,
              requestTimeout: const Duration(seconds: 15),
              httpClient: MockClient(
                (_) => Completer<http.Response>().future,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Drain bootstrap (_restore) before the explicit authenticate under test.
      container.listen(deviceAuthProvider, (_, _) {});
      async.flushMicrotasks();
      expect(container.read(deviceAuthProvider).loading, isFalse);

      unawaited(
        container.read(deviceAuthProvider.notifier).authenticate(
              deviceKey: 'dk_test',
              deviceSecret: 'ds_test',
            ),
      );
      async.flushMicrotasks();
      expect(container.read(deviceAuthProvider).loading, isTrue);

      async.elapse(const Duration(seconds: 15));
      async.flushMicrotasks();

      final state = container.read(deviceAuthProvider);
      expect(state.loading, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(
        state.error,
        "Can't reach the server. Check the connection and try again.",
      );
    });
  });
}
