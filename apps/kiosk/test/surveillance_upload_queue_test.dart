import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:skp_kiosk/features/surveillance/data/surveillance_upload_queue.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('skp_surv_q');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('stats separate pending and failed items', () async {
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    final ok = File(p.join(dir.path, '2026-09-03', '143052_abc.mp4'));
    final bad = File(p.join(dir.path, '2026-09-03', '143152_def.mp4'));
    ok.parent.createSync(recursive: true);
    ok.writeAsBytesSync(List<int>.filled(2048, 1));
    bad.writeAsBytesSync(List<int>.filled(16, 1));

    await queue.enqueue(path: ok.path, bytes: 2048);
    await queue.enqueue(path: bad.path, bytes: 16);
    await queue.markFailed(bad.path, error: 'invalid_segment');

    final stats = queue.stats();
    expect(stats.pendingCount, 1);
    expect(stats.failedCount, 1);
    expect(stats.lastError, 'invalid_segment');
    expect(queue.due(), hasLength(1));
    expect(queue.due().single.path, ok.path);
  });
}
