import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/runtime/liveness_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('skp_liveness_');
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('writeNow creates liveness.txt with an ISO timestamp', () async {
    final path = '${tempDir.path}${Platform.pathSeparator}liveness.txt';
    final writer = LivenessWriter(path: path);
    await writer.writeNow();

    final file = File(path);
    expect(file.existsSync(), isTrue);
    final raw = file.readAsStringSync().trim();
    expect(DateTime.parse(raw).isUtc, isTrue);
    expect(writer.lastWriteAt, isNotNull);
  });

  test('start schedules periodic writes', () {
    fakeAsync((async) {
      final path = '${tempDir.path}${Platform.pathSeparator}liveness_tick.txt';
      var now = DateTime.utc(2026, 1, 1, 12);
      final writer = LivenessWriter(
        path: path,
        interval: const Duration(seconds: 15),
        clock: () => now,
      );

      writer.start();
      async.flushMicrotasks();
      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsStringSync().trim(), now.toIso8601String());

      now = now.add(const Duration(seconds: 15));
      async.elapse(const Duration(seconds: 15));
      async.flushMicrotasks();
      expect(File(path).readAsStringSync().trim(), now.toIso8601String());

      writer.stop();
    });
  });
}
