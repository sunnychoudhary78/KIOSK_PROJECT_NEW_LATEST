import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/core/network/api_client.dart';

const _maxQueue = 500;
const _flushBatch = 50;
const _flushAtPending = 25;
const _flushInterval = Duration(seconds: 8);
const _dedupeWindow = Duration(seconds: 15);

class _QueuedLog {
  _QueuedLog({
    required this.level,
    required this.category,
    required this.event,
    required this.message,
    required this.occurredAt,
    this.metadata,
    this.correlationId,
  });

  final String level;
  final String category;
  final String event;
  final String message;
  final DateTime occurredAt;
  final Map<String, dynamic>? metadata;
  final String? correlationId;

  String get dedupeKey => '$category|$event|$message';

  Map<String, dynamic> toJson() => {
        'level': level,
        'category': category,
        'event': event,
        'message': message.length > 500 ? message.substring(0, 500) : message,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        if (correlationId != null && correlationId!.isNotEmpty)
          'correlationId': correlationId,
        if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
      };
}

/// Buffers [AppLogger.log] events and POSTs them to `/diagnostics/logs`.
class DiagnosticLogUploader {
  DiagnosticLogUploader(this._ref) {
    AppLogger.sink = _enqueue;
    _timer = Timer.periodic(_flushInterval, (_) => unawaited(flush()));
    _ref.onDispose(() {
      _timer?.cancel();
      if (identical(AppLogger.sink, _enqueue)) {
        AppLogger.sink = null;
      }
    });
  }

  final Ref _ref;
  final List<_QueuedLog> _queue = [];
  Timer? _timer;
  bool _flushing = false;
  String? _lastDedupeKey;
  DateTime? _lastDedupeAt;

  ApiClient get _api => _ref.read(apiClientProvider);

  void _enqueue({
    required String level,
    required String category,
    required String event,
    required String message,
    Map<String, dynamic>? metadata,
    String? correlationId,
  }) {
    final now = DateTime.now().toUtc();
    final entry = _QueuedLog(
      level: level,
      category: category,
      event: event,
      message: message,
      occurredAt: now,
      metadata: metadata,
      correlationId: correlationId,
    );
    final key = entry.dedupeKey;
    if (_lastDedupeKey == key &&
        _lastDedupeAt != null &&
        now.difference(_lastDedupeAt!) < _dedupeWindow) {
      return;
    }
    _lastDedupeKey = key;
    _lastDedupeAt = now;

    while (_queue.length >= _maxQueue) {
      _queue.removeAt(0);
    }
    _queue.add(entry);
    if (_queue.length >= _flushAtPending) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    if (!_ref.read(deviceAuthProvider).isAuthenticated) return;

    _flushing = true;
    try {
      while (_queue.isNotEmpty) {
        if (!_ref.read(deviceAuthProvider).isAuthenticated) break;
        final batch = _queue.take(_flushBatch).toList();
        try {
          await _api.post(
            '/diagnostics/logs',
            body: {'logs': batch.map((e) => e.toJson()).toList()},
          );
          _queue.removeRange(0, batch.length);
        } catch (_) {
          // Keep queued; try again next interval. Avoid tight retry loop.
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }
}

final diagnosticLogUploaderProvider = Provider<DiagnosticLogUploader>((ref) {
  return DiagnosticLogUploader(ref);
});
