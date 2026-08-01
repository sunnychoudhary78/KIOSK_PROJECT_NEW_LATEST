import 'dart:convert';
import 'dart:io';

class DeviceCredentials {
  const DeviceCredentials({
    required this.deviceKey,
    required this.deviceSecret,
  });

  final String deviceKey;
  final String deviceSecret;
}

/// Plugin-free credential persistence for Windows kiosk.
/// Stores under %APPDATA%/SmartKiosk/device_credentials.json
class DeviceCredentialStore {
  Future<File> _credentialsFile() async {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      throw StateError('APPDATA environment variable is not set');
    }
    final dir = Directory('$appData${Platform.pathSeparator}SmartKiosk');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}device_credentials.json');
  }

  Future<DeviceCredentials?> load() async {
    final file = await _credentialsFile();
    if (!await file.exists()) {
      return null;
    }
    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final deviceKey = json['deviceKey']?.toString() ?? '';
      final deviceSecret = json['deviceSecret']?.toString() ?? '';
      if (deviceKey.isEmpty || deviceSecret.isEmpty) {
        return null;
      }
      return DeviceCredentials(deviceKey: deviceKey, deviceSecret: deviceSecret);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(DeviceCredentials credentials) async {
    final file = await _credentialsFile();
    final payload = jsonEncode({
      'deviceKey': credentials.deviceKey,
      'deviceSecret': credentials.deviceSecret,
    });
    await file.writeAsString(payload, flush: true);
  }

  Future<void> clear() async {
    final file = await _credentialsFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
