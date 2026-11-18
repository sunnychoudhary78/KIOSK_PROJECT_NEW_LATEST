import 'dart:io';

/// Override for unit tests. Production uses `C:\Kiosk` on Windows.
String? kioskRuntimeRootOverride;

/// Root for shell/watchdog/liveness/logs on the locked-down device.
String get kioskRuntimeRoot {
  final override = kioskRuntimeRootOverride;
  if (override != null && override.isNotEmpty) {
    return override;
  }
  if (Platform.isWindows) {
    return r'C:\Kiosk';
  }
  // Non-Windows: keep under temp so laptop/CI does not create C:\Kiosk.
  return Directory.systemTemp.path;
}

String get kioskRuntimeDir => '$kioskRuntimeRoot${Platform.pathSeparator}runtime';

String get kioskLogsDir => '$kioskRuntimeRoot${Platform.pathSeparator}logs';

String get kioskLivenessPath =>
    '$kioskRuntimeDir${Platform.pathSeparator}liveness.txt';

String get kioskAppLogPath => '$kioskLogsDir${Platform.pathSeparator}app.log';
