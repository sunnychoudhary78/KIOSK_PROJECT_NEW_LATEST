import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:skp_kiosk/features/surveillance/data/surveillance_upload_queue.dart';

void main() {
  late Directory dir;
  late SurveillanceUploadQueue queue;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('skp_surv_queue');
    queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  File writeMp4(String relative, {int size = 8}) {
    final file = File(p.join(dir.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List<int>.filled(size, 1));
    return file;
  }

  test('enqueues unique paths and persists across reload', () async {
    final file = writeMp4(p.join('2026-09-03', '143052_abc.mp4'), size: 12);
    await queue.enqueue(path: file.path, bytes: 12, now: DateTime.utc(2026, 9, 3, 14));
    await queue.enqueue(path: file.path, bytes: 12, now: DateTime.utc(2026, 9, 3, 15));
    expect(queue.items, hasLength(1));
    expect(queue.items.single.recordedOn, '2026-09-03');

    final reloaded = SurveillanceUploadQueue(queueFile: queue.queueFile);
    await reloaded.load();
    expect(reloaded.items, hasLength(1));
    expect(reloaded.items.single.filename, '143052_abc.mp4');
    expect(reloaded.items.single.bytes, 12);
  });

  test('scanLeftovers picks completed mp4s and ignores in-progress', () async {
    writeMp4(p.join('2026-09-03', '143052_abc.mp4'));
    writeMp4(p.join('2026-09-03', surveillanceInProgressName));
    await queue.scanLeftovers(now: DateTime.utc(2026, 9, 3));
    expect(queue.items, hasLength(1));
    expect(queue.items.single.filename, '143052_abc.mp4');
  });

  test('enqueue rejects in-progress files', () async {
    final leftover = writeMp4(p.join('2026-09-03', surveillanceInProgressName));
    final item = await queue.enqueue(path: leftover.path);
    expect(item, isNull);
    expect(queue.items, isEmpty);
  });

  test('backoff without deleting the file', () async {
    final file = writeMp4(p.join('2026-09-03', '143052_abc.mp4'));
    await queue.enqueue(path: file.path, now: DateTime.utc(2026, 9, 3, 14));
    await queue.markAttempt(file.path, now: DateTime.utc(2026, 9, 3, 14));
    expect(file.existsSync(), isTrue);
    expect(queue.items.single.attempts, 1);
    expect(queue.due(now: DateTime.utc(2026, 9, 3, 14)), isEmpty);
    expect(queue.due(now: DateTime.utc(2026, 9, 3, 14, 0, 6)), hasLength(1));
    expect(surveillanceBackoffFor(1), const Duration(seconds: 5));
    expect(surveillanceBackoffFor(5), const Duration(seconds: 300));
  });
}
