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
    AppLogger.maxLogBytesOverride = 64;
    AppLogger.maxRotatedFilesOverride = 4;
  });

  tearDown(() {
    AppLogger.fileLogPathOverride = null;
    AppLogger.maxLogBytesOverride = null;
    AppLogger.maxRotatedFilesOverride = null;
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
    file.writeAsStringSync('x' * ((AppLogger.maxLogBytesOverride ?? 0) + 10));
    AppLogger.info('after-rotate');
    expect(File('$logPath.1').existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('after-rotate'));
  });

  test('chains rotated files and drops the oldest', () {
    final file = File(logPath);
    file.parent.createSync(recursive: true);
    File('$logPath.1').writeAsStringSync('gen-1');
    File('$logPath.2').writeAsStringSync('gen-2');
    File('$logPath.3').writeAsStringSync('gen-3');
    file.writeAsStringSync('x' * ((AppLogger.maxLogBytesOverride ?? 0) + 10));

    AppLogger.info('after-first-rotate');

    expect(File('$logPath.1').readAsStringSync(), contains('x'));
    expect(File('$logPath.2').readAsStringSync(), 'gen-1');
    expect(File('$logPath.3').readAsStringSync(), 'gen-2');
    expect(File('$logPath.4').readAsStringSync(), 'gen-3');
    expect(file.readAsStringSync(), contains('after-first-rotate'));

    file.writeAsStringSync('y' * ((AppLogger.maxLogBytesOverride ?? 0) + 10));
    AppLogger.info('after-second-rotate');

    expect(File('$logPath.1').readAsStringSync(), contains('y'));
    expect(File('$logPath.2').readAsStringSync(), contains('x'));
    expect(File('$logPath.3').readAsStringSync(), 'gen-1');
    expect(File('$logPath.4').readAsStringSync(), 'gen-2');
    expect(File('$logPath.4').readAsStringSync(), isNot(contains('gen-3')));
    expect(file.readAsStringSync(), contains('after-second-rotate'));
  });
}
