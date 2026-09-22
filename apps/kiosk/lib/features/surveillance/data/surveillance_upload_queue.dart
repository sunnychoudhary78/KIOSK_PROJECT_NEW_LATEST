import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

const surveillanceQueueFileName = 'upload-queue.json';
const surveillanceInProgressName = '.inprogress.mp4';
const surveillancePendingStatus = 'pending';
const surveillancePendingDeleteStatus = 'uploaded_pending_delete';

final _dateFolder = RegExp(r'^\d{4}-\d{2}-\d{2}$');

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

  bool get isPendingDelete => status == surveillancePendingDeleteStatus;

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
    );
  }
}

Duration surveillanceBackoffFor(int attempts) {
  final exp = math.max(0, attempts - 1);
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

  Future<void> load() async {
    _items.clear();
    if (!queueFile.existsSync()) {
      return;
    }
    try {
      final decoded = jsonDecode(await queueFile.readAsString());
      final list = decoded is Map ? decoded['items'] : decoded;
      if (list is! List) {
        return;
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
    }
  }

  Future<void> save() async {
    await queueFile.parent.create(recursive: true);
    final payload = jsonEncode({
      'items': items.map((item) => item.toJson()).toList(),
    });
    await queueFile.writeAsString(payload);
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

  Future<void> scanLeftovers({DateTime? now}) async {
    if (!root.existsSync()) {
      return;
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
  }

  List<SurveillanceQueueItem> due({DateTime? now}) {
    final utc = (now ?? DateTime.now()).toUtc();
    return items.where((item) => !item.nextAttemptAt.isAfter(utc)).toList();
  }

  Future<void> markAttempt(String path, {DateTime? now}) async {
    final item = _items[_key(path)];
    if (item == null) {
      return;
    }
    item.attempts += 1;
    item.nextAttemptAt = (now ?? DateTime.now()).toUtc().add(surveillanceBackoffFor(item.attempts));
    await save();
  }

  Future<void> markUploadedPendingDelete(String path, {required String segmentId}) async {
    final item = _items[_key(path)];
    if (item == null) {
      return;
    }
    item.segmentId = segmentId;
    item.status = surveillancePendingDeleteStatus;
    await save();
  }

  Future<void> remove(String path) async {
    _items.remove(_key(path));
    await save();
  }
}
