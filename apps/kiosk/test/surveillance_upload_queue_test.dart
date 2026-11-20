import 'dart:convert';
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
    expect(stats.dueCount, 1);
    expect(stats.lastError, 'invalid_segment');
    expect(queue.due(), hasLength(1));
    expect(queue.due().single.path, ok.path);
  });

  test('surveillanceBackoffFor stays at or under 300s for high attempt counts', () {
    for (var attempts = 1; attempts <= 100; attempts++) {
      expect(
        surveillanceBackoffFor(attempts).inSeconds,
        lessThanOrEqualTo(300),
        reason: 'attempts=$attempts',
      );
    }
    expect(surveillanceBackoffFor(1).inSeconds, 5);
    expect(surveillanceBackoffFor(2).inSeconds, 15);
    expect(surveillanceBackoffFor(6).inSeconds, 300);
    expect(surveillanceBackoffFor(43).inSeconds, 300);
  });

  test('healSchedules resets far-future nextAttemptAt from poisoned field queues', () async {
    final now = DateTime.utc(2026, 11, 20, 6);
    final mp4 = File(p.join(dir.path, '2026-11-16', '174555_595FAA03716E.mp4'));
    mp4.parent.createSync(recursive: true);
    mp4.writeAsBytesSync(List<int>.filled(2048, 1));

    final queueFile = File(p.join(dir.path, surveillanceQueueFileName));
    await queueFile.writeAsString(
      jsonEncode({
        'items': [
          {
            'path': mp4.path,
            'filename': '174555_595FAA03716E.mp4',
            'bytes': 90060846,
            'recordedOn': '2026-11-16',
            'enqueuedAt': '2026-11-20T05:55:55.920606Z',
            'attempts': 43,
            'nextAttemptAt': '+254488-12-21T19:30:01.065291Z',
            'segmentId': null,
            'status': 'pending',
            'lastError': 'unauthorized',
          },
        ],
      }),
    );

    final queue = SurveillanceUploadQueue(queueFile: queueFile);
    final healed = await queue.load();
    // load uses DateTime.now — re-heal with fixed clock for due assertion
    await queue.healSchedules(now: now);

    expect(healed, greaterThan(0));
    expect(queue.items, hasLength(1));
    expect(
      queue.items.single.nextAttemptAt.isAfter(now.add(const Duration(hours: 1))),
      isFalse,
    );
    expect(queue.due(now: now), hasLength(1));
    // Single recent pending item is due — not over the count/age backlog gates.
    expect(
      surveillanceHasUploadBacklog(queue.stats(now: now), now: now),
      isFalse,
    );
  });

  test('surveillanceHasUploadBacklog ignores pending when dueCount is 0', () {
    expect(
      surveillanceHasUploadBacklog(
        const SurveillanceQueueStats(
          pendingCount: 30,
          failedCount: 0,
          dueCount: 0,
        ),
      ),
      isFalse,
    );
    expect(
      surveillanceHasUploadBacklog(
        SurveillanceQueueStats(
          pendingCount: surveillanceBacklogPendingLimit + 1,
          failedCount: 0,
          dueCount: surveillanceBacklogPendingLimit + 1,
        ),
      ),
      isTrue,
    );
    final now = DateTime.utc(2026, 9, 3, 12);
    expect(
      surveillanceHasUploadBacklog(
        SurveillanceQueueStats(
          pendingCount: 1,
          failedCount: 0,
          dueCount: 1,
          oldestQueuedAt: now.subtract(surveillanceBacklogMaxAge + const Duration(minutes: 1)),
        ),
        now: now,
      ),
      isTrue,
    );
    expect(
      surveillanceHasUploadBacklog(
        SurveillanceQueueStats(
          pendingCount: 1,
          failedCount: 0,
          dueCount: 0,
          oldestQueuedAt: now.subtract(surveillanceBacklogMaxAge + const Duration(minutes: 1)),
        ),
        now: now,
      ),
      isFalse,
    );
  });

  test('markAttempt never schedules more than max backoff ahead', () async {
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    final ok = File(p.join(dir.path, '2026-09-03', '143052_abc.mp4'));
    ok.parent.createSync(recursive: true);
    ok.writeAsBytesSync(List<int>.filled(2048, 1));
    await queue.enqueue(path: ok.path, bytes: 2048);

    final now = DateTime.utc(2026, 11, 20, 12);
    for (var i = 0; i < 50; i++) {
      await queue.markAttempt(ok.path, now: now, error: 'unauthorized');
    }
    final next = queue.items.single.nextAttemptAt;
    expect(next.difference(now) <= surveillanceMaxBackoff, isTrue);
    expect(next.year, lessThan(2100));
  });
}
