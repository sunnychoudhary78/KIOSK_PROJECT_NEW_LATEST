import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/device/data/device_credential_store.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final deviceCredentialStoreProvider = Provider<DeviceCredentialStore>((ref) {
  return DeviceCredentialStore();
});

class DeviceAuthState {
  const DeviceAuthState({
    this.accessToken,
    this.deviceId,
    this.deviceName,
    this.error,
    this.loading = false,
    this.bootstrapping = false,
  });

  final String? accessToken;
  final String? deviceId;
  final String? deviceName;
  final String? error;
  final bool loading;
  final bool bootstrapping;

  bool get isAuthenticated => accessToken != null;
}

class DeviceAuthNotifier extends Notifier<DeviceAuthState> {
  @override
  DeviceAuthState build() {
    Future.microtask(_restoreSession);
    return const DeviceAuthState(bootstrapping: true, loading: true);
  }

  ApiClient get _api => ref.read(apiClientProvider);
  DeviceCredentialStore get _store => ref.read(deviceCredentialStoreProvider);

  Future<void> _restoreSession() async {
    try {
      final saved = await _store.load();
      if (saved == null) {
        state = const DeviceAuthState();
        return;
      }
      await authenticate(
        deviceKey: saved.deviceKey,
        deviceSecret: saved.deviceSecret,
        persist: false,
      );
    } catch (error) {
      state = DeviceAuthState(error: _messageFor(error));
    }
  }

  Future<void> authenticate({
    required String deviceKey,
    required String deviceSecret,
    bool persist = true,
  }) async {
    final trimmedKey = deviceKey.trim();
    final trimmedSecret = deviceSecret.trim();
    if (trimmedKey.isEmpty || trimmedSecret.isEmpty) {
      state = const DeviceAuthState(error: 'Device key and secret are required');
      return;
    }

    state = DeviceAuthState(loading: true, bootstrapping: state.bootstrapping);
    try {
      final result = await _api.post(
        '/auth/device/token',
        body: {
          'deviceKey': trimmedKey,
          'deviceSecret': trimmedSecret,
        },
      );
      final token = result['accessToken'] as String;
      final deviceId = result['deviceId'] as String?;
      final deviceName = result['deviceName'] as String?;
      _api.setAccessToken(token);

      if (persist) {
        await _store.save(
          DeviceCredentials(deviceKey: trimmedKey, deviceSecret: trimmedSecret),
        );
      }

      if (deviceId != null && deviceId.isNotEmpty) {
        try {
          await _api.post('/devices/$deviceId/heartbeat');
        } catch (_) {
          // Activation still succeeds if heartbeat fails briefly.
        }
      }

      state = DeviceAuthState(
        accessToken: token,
        deviceId: deviceId,
        deviceName: deviceName,
      );
    } catch (error) {
      state = DeviceAuthState(error: _messageFor(error));
    }
  }

  Future<void> deactivate() async {
    await _store.clear();
    _api.setAccessToken(null);
    state = const DeviceAuthState();
  }

  String _messageFor(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }
}

final deviceAuthProvider =
    NotifierProvider<DeviceAuthNotifier, DeviceAuthState>(DeviceAuthNotifier.new);
