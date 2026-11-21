import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

const surveillanceQueueFileName = 'upload-queue.json';
const surveillanceInProgressName = '.inprogress.mp4';
const surveillancePendingStatus = 'pending';
const surveillancePendingDeleteStatus = 'uploaded_pending_delete';
const surveillanceFailedStatus = 'failed';

/// Local segments below this size are never uploaded (corrupt/stub).
const surveillanceMinSegmentBytes = 1024;

/// Pause new recording when pending uploads exceed this count.
const surveillanceBacklogPendingLimit = 20;

/// Pause new recording when the oldest pending item is older than this.
const surveillanceBacklogMaxAge = Duration(hours: 2);

/// Max backoff from [surveillanceBackoffFor] (5 * 3^5 = 1215 → capped at 300).
const surveillanceMaxBackoff = Duration(seconds: 300);

/// Schedules more than this ahead of now are treated as poisoned and healed.
const surveillanceHealScheduleHorizon = Duration(minutes: 10);

/// True when the upload queue is large/old enough to pause new recording.
///
/// High pending with [SurveillanceQueueStats.dueCount] == 0 does **not** pause
/// (poisoned far-future schedules); heal-on-load must make items due first.
bool surveillanceHasUploadBacklog(
  SurveillanceQueueStats stats, {
  DateTime? now,
}) {
  if (stats.dueCount <= 0) {
    return false;
  }
  if (stats.pendingCount > surveillanceBacklogPendingLimit) {
    return true;
  }
  final oldest = stats.oldestQueuedAt;
  if (oldest == null) {
    return false;
  }
  final utc = (now ?? DateTime.now()).toUtc();
  return utc.difference(oldest.toUtc()) > surveillanceBacklogMaxAge;
}

final _dateFolder = RegExp(r'^\d{4}-\d{2}-\d{2}$');

class SurveillanceQueueStats {
  const SurveillanceQueueStats({
    required this.pendingCount,
    required this.failedCount,
    this.dueCount = 0,
    this.oldestQueuedAt,
    this.lastError,
  });

  final int pendingCount;
  final int failedCount;
  final int dueCount;
  final DateTime? oldestQueuedAt;
  final String? lastError;
}

class SurveillanceQueueItem {
  SurveillanceQueueItem({
    required this.path,
    required this.filename,
    required this.bytes,
    required this.recordedOn,
    required this.enqueuedAt,
    this.attempts = 0,
    DateTime? nextAttemptAt,
    this.segmentId,
    this.status = surveillancePendingStatus,
    this.lastError,
  }) : nextAttemptAt = nextAttemptAt ?? enqueuedAt;

  final String path;
  final String filename;
  int bytes;
  final String recordedOn;
  final DateTime enqueuedAt;
  int attempts;
  DateTime nextAttemptAt;
  String? segmentId;
  String status;
  String? lastError;

  bool get isPendingDelete => status == surveillancePendingDeleteStatus;
  bool get isFailed => status == surveillanceFailedStatus;

  Map<String, dynamic> toJson() => {
        'path': path,
        'filename': filename,
        'bytes': bytes,
        'recordedOn': recordedOn,
        'enqueuedAt': enqueuedAt.toUtc().toIso8601String(),
        'attempts': attempts,
        'nextAttemptAt': nextAttemptAt.toUtc().toIso8601String(),
        'segmentId': segmentId,
        'status': status,
        'lastError': lastError,
      };

  factory SurveillanceQueueItem.fromJson(Map<String, dynamic> json) {
    return SurveillanceQueueItem(
      path: json['path'] as String,
      filename: json['filename'] as String,
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      recordedOn: json['recordedOn'] as String? ?? '',
      enqueuedAt: DateTime.tryParse(json['enqueuedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAt:
          DateTime.tryParse(json['nextAttemptAt'] as String? ?? '')?.toUtc(),
      segmentId: json['segmentId'] as String?,
      status: json['status'] as String? ?? surveillancePendingStatus,
      lastError: json['lastError'] as String?,
    );
  }
}

/// Exponential backoff capped at 300s. Exponent is capped before pow so large
/// attempt counts can never produce century-scale [Duration]s.
Duration surveillanceBackoffFor(int attempts) {
  final exp = math.min(5, math.max(0, attempts - 1));
  final seconds = math.min(300, 5 * math.pow(3, exp).toInt());
  return Duration(seconds: seconds);
}

String? recordedOnFromPath(String path, {DateTime? now}) {
  final parent = p.basename(p.dirname(path));
  if (_dateFolder.hasMatch(parent)) {
    return parent;
  }
  final utc = (now ?? DateTime.now()).toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}

bool isCompletedSegmentPath(String path) {
  final name = p.basename(path);
  if (name.toLowerCase() == surveillanceInProgressName) {
    return false;
  }
  return name.toLowerCase().endsWith('.mp4');
}

/// Durable JSON queue of completed MP4s waiting to upload.
class SurveillanceUploadQueue {
  SurveillanceUploadQueue({required this.queueFile});

  final File queueFile;
  final Map<String, SurveillanceQueueItem> _items = {};

  Directory get root => queueFile.parent;

  List<SurveillanceQueueItem> get items =>
      _items.values.toList()..sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));

  String _key(String path) => p.normalize(path);

  /// Loads durable queue JSON and heals poisoned schedules. Returns heal count.
  Future<int> load() async {
    _items.clear();
    if (!queueFile.existsSync()) {
      return 0;
    }
    try {
      final decoded = jsonDecode(await queueFile.readAsString());
      final list = decoded is Map ? decoded['items'] : decoded;
      if (list is! List) {
        return 0;
      }
      for (final raw in list) {
        if (raw is! Map) {
          continue;
        }
        final item = SurveillanceQueueItem.fromJson(Map<String, dynamic>.from(raw));
        _items[_key(item.path)] = item;
      }
    } on FormatException {
      _items.clear();
      return 0;
    }
    return healSchedules();
  }

  /// Resets absurd far-future [SurveillanceQueueItem.nextAttemptAt] values.
  /// Returns how many items were healed.
  Future<int> healSchedules({DateTime? now}) async {
    final utc = (now ?? DateTime.now()).toUtc();
    final horizon = utc.add(surveillanceHealScheduleHorizon);
    var healed = 0;
    for (final item in _items.values) {
      if (item.isFailed) {
        continue;
      }
      if (item.nextAttemptAt.isAfter(horizon)) {
        item.nextAttemptAt = utc;
        healed += 1;
      }
    }

    // Pending but nothing due after clamp → force all pending schedules to now.
    final after = stats(now: utc);
    if (after.pendingCount > 0 && after.dueCount == 0) {
      for (final item in _items.values) {
        if (item.isFailed || item.isPendingDelete) {
          continue;
        }
        if (item.nextAttemptAt.isAfter(utc)) {
          item.nextAttemptAt = utc;
          healed += 1;
        }
      }
    }

    if (healed > 0) {
      await save();
    }
    return healed;
  }

  Future<void> save() async {
    await queueFile.parent.create(recursive: true);
    final payload = jsonEncode({
      'items': items.map((item) => item.toJson()).toList(),
    });
    await queueFile.writeAsString(payload);
  }

  /// Best-effort delete of a stub/corrupt local segment file.
  static void deleteSegmentFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  Future<SurveillanceQueueItem?> enqueue({
    required String path,
    int? bytes,
    DateTime? now,
  }) async {
    if (!isCompletedSegmentPath(path)) {
      return null;
    }
    final key = _key(path);
    final file = File(path);
    final existing = _items[key];
    if (existing != null) {
      if (bytes != null && bytes > 0) {
        existing.bytes = bytes;
      }
      await save();
      return existing;
    }
    if (!file.existsSync()) {
      return null;
    }
    final size = bytes != null && bytes > 0 ? bytes : file.lengthSync();
    if (size < surveillanceMinSegmentBytes) {
      deleteSegmentFile(path);
      return null;
    }
    final utc = (now ?? DateTime.now()).toUtc();
    final item = SurveillanceQueueItem(
      path: path,
      filename: p.basename(path),
      bytes: size,
      recordedOn: recordedOnFromPath(path, now: utc) ?? '',
      enqueuedAt: utc,
    );
    _items[key] = item;
    await save();
    return item;
  }

  /// Removes sticky failed stub rows (`invalid_segment`) and their files.
  /// Returns how many items were pruned.
  Future<int> pruneInvalidSegments() async {
    final doomed = _items.values
        .where(
          (item) => item.isFailed && item.lastError == 'invalid_segment',
        )
        .toList();
    if (doomed.isEmpty) {
      return 0;
    }
    for (final item in doomed) {
      deleteSegmentFile(item.path);
      _items.remove(_key(item.path));
    }
    await save();
    return doomed.length;
  }

  /// Force all non-failed pending items due now (Admin "Unstick queue").
  Future<int> healDueNow({DateTime? now}) async {
    final utc = (now ?? DateTime.now()).toUtc();
    var healed = await healSchedules(now: utc);
    for (final item in _items.values) {
      if (item.isFailed || item.isPendingDelete) {
        continue;
      }
      if (item.nextAttemptAt.isAfter(utc)) {
        item.nextAttemptAt = utc;
        healed += 1;
      }
    }
    if (healed > 0) {
      await save();
    }
    return healed;
  }

  static bool isRecoverableUploadError(String? error) {
    if (error == null || error.isEmpty) {
      return true;
    }
    if (error == 'invalid_segment') {
      return false;
    }
    return true;
  }

  /// Re-open failed (non-stub) items as pending and due now.
  Future<int> retryRecoverableFailures({DateTime? now}) async {
    final utc = (now ?? DateTime.now()).toUtc();
    var retried = 0;
    for (final item in _items.values) {
      if (item.isPendingDelete) {
        continue;
      }
      if (!item.isFailed && item.lastError == null) {
        continue;
      }
      if (!isRecoverableUploadError(item.lastError)) {
        continue;
      }
      // Skip stubs that somehow stayed pending with tiny size.
      if (item.bytes > 0 && item.bytes < surveillanceMinSegmentBytes) {
        continue;
      }
      item.status = surveillancePendingStatus;
      item.lastError = null;
      item.nextAttemptAt = utc;
      retried += 1;
    }
    if (retried > 0) {
      await save();
    }
    return retried;
  }

  /// Scans leftover MP4s into the queue and heals schedules. Returns heal count.
  Future<int> scanLeftovers({DateTime? now}) async {
    if (!root.existsSync()) {
      return 0;
    }
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (p.basename(entity.path) == surveillanceQueueFileName) {
        continue;
      }
      await enqueue(path: entity.path, now: now);
    }
    final missing = <String>[];
    for (final item in _items.values) {
      if (!File(item.path).existsSync()) {
        missing.add(_key(item.path));
      }
    }
    for (final key in missing) {
      _items.remove(key);
    }
    await save();
    return healSchedules(now: now);
  }

  List<SurveillanceQueueItem> due({DateTime? now}) {
    final utc = (now ?? DateTime.now()).toUtc();
    return items
        .where((item) => !item.isFailed && !item.nextAttemptAt.isAfter(utc))
        .toList();
  }

  SurveillanceQueueStats stats({DateTime? now}) {
    final utc = (now ?? DateTime.now()).toUtc();
    final pending = items.where((item) => !item.isFailed && !item.isPendingDelete);
    final failed = items.where((item) => item.isFailed);
    final dueItems = due(now: utc);
    DateTime? oldest;
    String? lastError;
    for (final item in items) {
      if (item.isFailed || item.isPendingDelete) {
        if (item.isFailed && item.lastError != null) {
          lastError = item.lastError;
        }
        continue;
      }
      if (oldest == null || item.enqueuedAt.isBefore(oldest)) {
        oldest = item.enqueuedAt;
      }
      if (item.lastError != null) {
        lastError = item.lastError;
      }
    }
    return SurveillanceQueueStats(
      pendingCount: pending.length,
      failedCount: failed.length,
      dueCount: dueItems.length,
      oldestQueuedAt: oldest,
      lastError: lastError ?? (failed.isEmpty ? null : failed.last.lastError),
    );
  }

  Future<void> markAttempt(String path, {DateTime? now, String? error}) async {
    final item = _items[_key(path)];
    if (item == null) {
      return;
    }
    item.attempts += 1;
    item.lastError = error ?? item.lastError;
    item.nextAttemptAt =
        (now ?? DateTime.now()).toUtc().add(surveillanceBackoffFor(item.attempts));
    await save();
  }

  Future<void> markFailed(String path, {required String error}) async {
    final item = _items[_key(path)];
    if (item == null) {
      return;
    }
    item.status = surveillanceFailedStatus;
    item.lastError = error;
    await save();
  }

  Future<void> markUploadedPendingDelete(String path, {required String segmentId}) async {
    final item = _items[_key(path)];
    if (item == null) {
      return;
    }
    item.segmentId = segmentId;
    item.status = surveillancePendingDeleteStatus;
    item.lastError = null;
    await save();
  }

  Future<void> remove(String path) async {
    _items.remove(_key(path));
    await save();
  }
}
