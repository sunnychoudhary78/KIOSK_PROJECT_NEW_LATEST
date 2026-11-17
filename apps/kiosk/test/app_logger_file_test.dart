import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';

void main() {
  late Directory tempDir;
  late String logPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('skp_log_');
    logPath = '${tempDir.path}${Platform.pathSeparator}app.log';
    AppLogger.fileLogPathOverride = logPath;
    AppLogger.fileLoggingEnabled = true;
  });

  tearDown(() {
    AppLogger.fileLogPathOverride = null;
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('info appends to the on-disk log file', () {
    AppLogger.info('hello-disk');
    final file = File(logPath);
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('hello-disk'));
  });

  test('append does not throw when the path is invalid', () {
    // Illegal filename characters on Windows; non-existent root elsewhere.
    AppLogger.fileLogPathOverride = Platform.isWindows
        ? '${tempDir.path}${Platform.pathSeparator}bad<>:"|?*.log'
        : '/proc/skp_no_write/app.log';
    expect(() => AppLogger.warn('should-not-throw'), returnsNormally);
  });

  test('rotates when the log exceeds max size', () {
    final file = File(logPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('x' * (AppLogger.maxLogBytes + 10));
    AppLogger.info('after-rotate');
    expect(File('$logPath.1').existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('after-rotate'));
  });
}
