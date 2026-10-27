import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/jwt_utils.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/device/data/device_credential_store.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Set by [SurveillanceController] so heartbeats can report health without a
/// circular import between auth and surveillance modules.
Map<String, dynamic> Function()? surveillanceHeartbeatBodyBuilder;

/// Set by [PrinterHealthController] for printer SNMP/spooler health on heartbeat.
Map<String, dynamic> Function()? printerHeartbeatBodyBuilder;

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
    this.provisioned = false,
    this.stopped = false,
    this.surveillanceEnabled = false,
  });

  final String? accessToken;
  final String? deviceId;
  final String? deviceName;
  final String? error;
  final bool loading;
  final bool bootstrapping;

  /// Local key/secret exist. Never show the Activate form while this is true.
  final bool provisioned;

  /// Admin stopped this kiosk. Credentials stay on disk.
  final bool stopped;

  /// Admin started 24/7 local recording for this device.
  final bool surveillanceEnabled;

  bool get isAuthenticated => accessToken != null && !stopped;
}

class DeviceAuthNotifier extends Notifier<DeviceAuthState> {
  static const keepaliveInterval = Duration(minutes: 1);
  static const stoppedRetryInterval = Duration(seconds: 30);

  DeviceCredentials? _credentials;
  Timer? _loop;
  bool _tickInFlight = false;

  @override
  DeviceAuthState build() {
    ref.onDispose(() {
      _loop?.cancel();
    });
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
      _credentials = saved;
      await authenticate(
        deviceKey: saved.deviceKey,
        deviceSecret: saved.deviceSecret,
        persist: false,
      );
    } catch (error) {
      state = DeviceAuthState(
        provisioned: _credentials != null,
        error: _messageFor(error),
      );
      _armLoop();
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
      state = DeviceAuthState(
        provisioned: _credentials != null,
        error: 'Device key and secret are required',
      );
      return;
    }

    state = DeviceAuthState(
      loading: true,
      bootstrapping: state.bootstrapping,
      provisioned: _credentials != null,
      stopped: state.stopped,
      deviceName: state.deviceName,
      deviceId: state.deviceId,
      surveillanceEnabled: state.surveillanceEnabled,
    );
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
      var surveillanceEnabled = result['surveillanceEnabled'] == true;
      _api.setAccessToken(token);

      _credentials = DeviceCredentials(
        deviceKey: trimmedKey,
        deviceSecret: trimmedSecret,
      );
      if (persist) {
        await _store.save(_credentials!);
      }

      if (deviceId != null && deviceId.isNotEmpty) {
        try {
          final beat = await _api.post(
            '/devices/$deviceId/heartbeat',
            body: _surveillanceHeartbeatBody(),
          );
          if (beat.containsKey('surveillanceEnabled')) {
            surveillanceEnabled = beat['surveillanceEnabled'] == true;
          }
        } catch (error) {
          if (_isInactive(error)) {
            _enterStopped(deviceName: deviceName, deviceId: deviceId);
            return;
          }
        }
      }

      state = DeviceAuthState(
        accessToken: token,
        deviceId: deviceId,
        deviceName: deviceName,
        provisioned: true,
        surveillanceEnabled: surveillanceEnabled,
      );
      _armLoop();
    } catch (error) {
      if (_isInactive(error)) {
        if (persist && _credentials == null) {
          state = DeviceAuthState(error: _messageFor(error));
          return;
        }
        _enterStopped(deviceName: state.deviceName, deviceId: state.deviceId);
        return;
      }
      if (_isInvalidCredentials(error)) {
        await _clearInvalidCredentials(_messageFor(error));
        return;
      }
      _api.setAccessToken(null);
      state = DeviceAuthState(
        provisioned: _credentials != null,
        deviceName: state.deviceName,
        deviceId: state.deviceId,
        error: _messageFor(error),
      );
      _armLoop();
    }
  }

  Future<void> _clearInvalidCredentials(String message) async {
    _api.setAccessToken(null);
    _loop?.cancel();
    _loop = null;
    _credentials = null;
    await _store.clear();
    state = DeviceAuthState(error: message);
  }

  Future<void> _tick() async {
    if (_tickInFlight || !ref.mounted) {
      return;
    }
    _tickInFlight = true;
    try {
      final creds = _credentials ?? await _store.load();
      if (creds == null) {
        return;
      }
      _credentials = creds;

      final token = state.accessToken;
      if (state.stopped || token == null || isJwtExpired(token)) {
        await authenticate(
          deviceKey: creds.deviceKey,
          deviceSecret: creds.deviceSecret,
          persist: false,
        );
        return;
      }

      final deviceId = state.deviceId;
      if (deviceId == null || deviceId.isEmpty) {
        return;
      }
      try {
        final beat = await _api.post(
          '/devices/$deviceId/heartbeat',
          body: _surveillanceHeartbeatBody(),
        );
        final enabled = beat['surveillanceEnabled'] == true;
        if (enabled != state.surveillanceEnabled) {
          state = DeviceAuthState(
            accessToken: state.accessToken,
            deviceId: state.deviceId,
            deviceName: state.deviceName,
            provisioned: true,
            surveillanceEnabled: enabled,
          );
        }
      } catch (error) {
        if (_isInactive(error)) {
          _enterStopped(deviceName: state.deviceName, deviceId: deviceId);
        }
      }
    } finally {
      _tickInFlight = false;
    }
  }

  /// Posts the current heartbeat and acknowledges a pending printer refresh.
  /// Returns false when another heartbeat is already in flight.
  Future<bool> sendPrinterRefreshHeartbeat(String requestedAt) async {
    if (_tickInFlight || !ref.mounted || state.stopped) {
      return false;
    }
    final deviceId = state.deviceId;
    final token = state.accessToken;
    if (deviceId == null || deviceId.isEmpty || token == null || isJwtExpired(token)) {
      return false;
    }
    _tickInFlight = true;
    try {
      final body = _surveillanceHeartbeatBody();
      body['printerRefreshAck'] = requestedAt;
      final beat = await _api.post(
        '/devices/$deviceId/heartbeat',
        body: body,
      );
      final enabled = beat['surveillanceEnabled'] == true;
      if (enabled != state.surveillanceEnabled) {
        state = DeviceAuthState(
          accessToken: state.accessToken,
          deviceId: state.deviceId,
          deviceName: state.deviceName,
          provisioned: true,
          surveillanceEnabled: enabled,
        );
      }
      return true;
    } catch (error) {
      if (_isInactive(error)) {
        _enterStopped(deviceName: state.deviceName, deviceId: deviceId);
      }
      return false;
    } finally {
      _tickInFlight = false;
    }
  }

  void _enterStopped({String? deviceName, String? deviceId}) {
    _api.setAccessToken(null);
    state = DeviceAuthState(
      provisioned: true,
      stopped: true,
      deviceName: deviceName,
      deviceId: deviceId,
    );
    _armLoop();
  }

  void _armLoop() {
    _loop?.cancel();
    if (_credentials == null) {
      _loop = null;
      return;
    }
    final interval =
        state.stopped ? stoppedRetryInterval : keepaliveInterval;
    _loop = Timer.periodic(interval, (_) => unawaited(_tick()));
  }

  bool _isInactive(Object error) {
    return error is ApiException && error.code == 'device_inactive';
  }

  bool _isInvalidCredentials(Object error) {
    return error is ApiException && error.code == 'invalid_credentials';
  }

  String _messageFor(Object error) => userFacingError(error);

  Map<String, dynamic> _surveillanceHeartbeatBody() {
    final body = <String, dynamic>{};
    final surveillanceBuilder = surveillanceHeartbeatBodyBuilder;
    if (surveillanceBuilder != null) {
      try {
        body['surveillance'] = surveillanceBuilder();
      } catch (_) {
        body['surveillance'] = {
          'state': state.surveillanceEnabled ? 'stale' : 'off',
          'recording': false,
        };
      }
    } else {
      body['surveillance'] = {
        'state': state.surveillanceEnabled ? 'stale' : 'off',
        'recording': false,
      };
    }
    final printerBuilder = printerHeartbeatBodyBuilder;
    if (printerBuilder != null) {
      try {
        body['printer'] = printerBuilder();
      } catch (_) {
        // omit printer on builder failure
      }
    }
    return body;
  }
}

final deviceAuthProvider =
    NotifierProvider<DeviceAuthNotifier, DeviceAuthState>(DeviceAuthNotifier.new);
