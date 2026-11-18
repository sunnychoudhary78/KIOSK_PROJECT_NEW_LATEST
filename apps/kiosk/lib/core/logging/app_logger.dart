import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:skp_kiosk/core/runtime/kiosk_runtime_paths.dart';

typedef DiagnosticLogSink = void Function({
  required String level,
  required String category,
  required String event,
  required String message,
  Map<String, dynamic>? metadata,
  String? correlationId,
});

/// Console + optional remote diagnostic sink + best-effort on-disk log.
class AppLogger {
  static DiagnosticLogSink? sink;

  /// Override for tests. Null = use [kioskAppLogPath].
  static String? fileLogPathOverride;

  /// Max size before rotation (5 MB).
  static const int maxLogBytes = 5 * 1024 * 1024;

  /// Off by default so unit tests do not touch disk; [bootstrap] enables it.
  static bool fileLoggingEnabled = false;

  static void info(String message) {
    _emit('[SKP][INFO] $message');
  }

  static void warn(String message) {
    _emit('[SKP][WARN] $message');
  }

  static void error(String message, [Object? error]) {
    _emit('[SKP][ERROR] $message ${error ?? ''}'.trimRight());
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
    _emit('[SKP][$tag][$category] $event — $message');
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

  static void _emit(String line) {
    debugPrint(line);
    _appendFile(line);
  }

  static void _appendFile(String line) {
    if (!fileLoggingEnabled) {
      return;
    }
    try {
      final path = fileLogPathOverride ?? kioskAppLogPath;
      final file = File(path);
      file.parent.createSync(recursive: true);
      _rotateIfNeeded(file);
      final stamp = DateTime.now().toUtc().toIso8601String();
      file.writeAsStringSync(
        '$stamp $line\n',
        mode: FileMode.append,
        flush: false,
      );
    } catch (_) {
      // Never break call sites.
    }
  }

  static void _rotateIfNeeded(File file) {
    try {
      if (!file.existsSync()) {
        return;
      }
      if (file.lengthSync() < maxLogBytes) {
        return;
      }
      final rotated = File('${file.path}.1');
      if (rotated.existsSync()) {
        rotated.deleteSync();
      }
      file.renameSync(rotated.path);
    } catch (_) {}
  }
}
