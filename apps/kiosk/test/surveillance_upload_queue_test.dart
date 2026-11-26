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
    final failed = File(p.join(dir.path, '2026-09-03', '143152_def.mp4'));
    ok.parent.createSync(recursive: true);
    ok.writeAsBytesSync(List<int>.filled(2048, 1));
    failed.writeAsBytesSync(List<int>.filled(2048, 1));

    await queue.enqueue(path: ok.path, bytes: 2048);
    await queue.enqueue(path: failed.path, bytes: 2048);
    await queue.markFailed(failed.path, error: 'upload_failed');

    final stats = queue.stats();
    expect(stats.pendingCount, 1);
    expect(stats.failedCount, 1);
    expect(stats.dueCount, 1);
    expect(stats.lastError, 'upload_failed');
    expect(queue.due(), hasLength(1));
    expect(queue.due().single.path, ok.path);
  });

  test('enqueue discards tiny stub segments without queueing', () async {
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    final tiny = File(p.join(dir.path, '2026-09-03', '143152_tiny.mp4'));
    tiny.parent.createSync(recursive: true);
    tiny.writeAsBytesSync(List<int>.filled(16, 1));

    final item = await queue.enqueue(path: tiny.path, bytes: 16);
    expect(item, isNull);
    expect(queue.items, isEmpty);
    expect(tiny.existsSync(), isFalse);
  });

  test('scanLeftovers discards leftover tiny mp4s', () async {
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    final tiny = File(p.join(dir.path, '2026-09-03', '143152_tiny.mp4'));
    final ok = File(p.join(dir.path, '2026-09-03', '143052_ok.mp4'));
    tiny.parent.createSync(recursive: true);
    tiny.writeAsBytesSync(List<int>.filled(8, 1));
    ok.writeAsBytesSync(List<int>.filled(2048, 1));

    await queue.scanLeftovers();
    expect(tiny.existsSync(), isFalse);
    expect(queue.items, hasLength(1));
    expect(queue.items.single.path, ok.path);
  });

  test('flushAll clears queue and deletes segment files', () async {
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    final ok = File(p.join(dir.path, '2026-09-03', '143052_abc.mp4'));
    final leftover = File(p.join(dir.path, '2026-09-03', '150000_leftover.mp4'));
    ok.parent.createSync(recursive: true);
    ok.writeAsBytesSync(List<int>.filled(2048, 1));
    leftover.writeAsBytesSync(List<int>.filled(2048, 1));
    await queue.enqueue(path: ok.path, bytes: 2048);
    expect(queue.items, hasLength(1));

    final result = await queue.flushAll(deleteFiles: true);
    expect(result.flushed, 1);
    expect(result.deletedFiles, greaterThanOrEqualTo(2));
    expect(queue.items, isEmpty);
    expect(ok.existsSync(), isFalse);
    expect(leftover.existsSync(), isFalse);
  });

  test('healDueNow forces pending schedules to now', () async {
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    final ok = File(p.join(dir.path, '2026-09-03', '143052_abc.mp4'));
    ok.parent.createSync(recursive: true);
    ok.writeAsBytesSync(List<int>.filled(2048, 1));
    await queue.enqueue(path: ok.path, bytes: 2048);

    final now = DateTime.utc(2026, 11, 21, 12);
    await queue.markAttempt(ok.path, now: now, error: 'unauthorized');
    expect(queue.items.single.nextAttemptAt.isAfter(now), isTrue);

    final healed = await queue.healDueNow(now: now);
    expect(healed, greaterThan(0));
    expect(queue.due(now: now), hasLength(1));
  });

  test('retryRecoverableFailures reopens failed non-stub items', () async {
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    final ok = File(p.join(dir.path, '2026-09-03', '143052_abc.mp4'));
    ok.parent.createSync(recursive: true);
    ok.writeAsBytesSync(List<int>.filled(2048, 1));
    await queue.enqueue(path: ok.path, bytes: 2048);
    await queue.markFailed(ok.path, error: 'size_mismatch');

    final now = DateTime.utc(2026, 11, 21, 12);
    final retried = await queue.retryRecoverableFailures(now: now);
    expect(retried, 1);
    expect(queue.items.single.isFailed, isFalse);
    expect(queue.due(now: now), hasLength(1));
    expect(queue.items.single.lastError, isNull);
  });

  test('retryRecoverableFailures leaves invalid_segment failed', () async {
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    final ok = File(p.join(dir.path, '2026-09-03', '143052_abc.mp4'));
    ok.parent.createSync(recursive: true);
    ok.writeAsBytesSync(List<int>.filled(2048, 1));
    await queue.enqueue(path: ok.path, bytes: 2048);
    await queue.markFailed(ok.path, error: 'invalid_segment');

    final retried = await queue.retryRecoverableFailures();
    expect(retried, 0);
    expect(queue.items.single.isFailed, isTrue);
  });

  test('pruneInvalidSegments removes sticky stub failures', () async {
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    final stub = File(p.join(dir.path, '2026-09-03', '143152_stub.mp4'));
    stub.parent.createSync(recursive: true);
    stub.writeAsBytesSync(List<int>.filled(0, 0));

    // Seed a failed invalid_segment row as older builds left behind.
    final queueFile = File(p.join(dir.path, surveillanceQueueFileName));
    await queueFile.writeAsString(
      jsonEncode({
        'items': [
          {
            'path': stub.path,
            'filename': '143152_stub.mp4',
            'bytes': 0,
            'recordedOn': '2026-09-03',
            'enqueuedAt': '2026-09-03T14:31:52.000Z',
            'attempts': 0,
            'nextAttemptAt': '2026-09-03T14:31:52.000Z',
            'segmentId': null,
            'status': 'failed',
            'lastError': 'invalid_segment',
          },
        ],
      }),
    );
    await queue.load();
    expect(queue.items, hasLength(1));

    final pruned = await queue.pruneInvalidSegments();
    expect(pruned, 1);
    expect(queue.items, isEmpty);
    expect(stub.existsSync(), isFalse);
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

  test('recordedOn comes from UTC day folder in path, not wall-clock now', () async {
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    // After midnight the filename HHmmss rolls over; folder date must still win
    // so admin startedAt stays aligned with the segment's real UTC day.
    final clip = File(p.join(dir.path, '2026-11-26', '000001_post_midnight.mp4'));
    clip.parent.createSync(recursive: true);
    clip.writeAsBytesSync(List<int>.filled(2048, 1));

    final item = await queue.enqueue(
      path: clip.path,
      bytes: 2048,
      now: DateTime.utc(2026, 11, 26, 0, 0, 15),
    );
    expect(item, isNotNull);
    expect(item!.recordedOn, '2026-11-26');
    expect(recordedOnFromPath(clip.path), '2026-11-26');
  });
}
