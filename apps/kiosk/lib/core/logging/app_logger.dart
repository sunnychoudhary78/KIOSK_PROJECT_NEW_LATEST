import 'package:flutter/foundation.dart';

typedef DiagnosticLogSink = void Function({
  required String level,
  required String category,
  required String event,
  required String message,
  Map<String, dynamic>? metadata,
  String? correlationId,
});

/// Console + optional remote diagnostic sink (set by the uploader).
class AppLogger {
  static DiagnosticLogSink? sink;

  static void info(String message) {
    debugPrint('[SKP][INFO] $message');
  }

  static void warn(String message) {
    debugPrint('[SKP][WARN] $message');
  }

  static void error(String message, [Object? error]) {
    debugPrint('[SKP][ERROR] $message ${error ?? ''}');
  }

  /// Local console + enqueue for Admin diagnostic upload when [sink] is set.
  static void log({
    required String level,
    required String category,
    required String event,
    required String message,
    Map<String, dynamic>? metadata,
    String? correlationId,
  }) {
    final tag = level.toUpperCase();
    debugPrint('[SKP][$tag][$category] $event — $message');
    final s = sink;
    if (s == null) return;
    try {
      s(
        level: level,
        category: category,
        event: event,
        message: message,
        metadata: metadata,
        correlationId: correlationId,
      );
    } catch (_) {
      // Never break call sites.
    }
  }
}
