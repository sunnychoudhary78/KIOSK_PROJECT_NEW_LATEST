import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message) {
    debugPrint('[SKP][INFO] $message');
  }

  static void error(String message, [Object? error]) {
    debugPrint('[SKP][ERROR] $message ${error ?? ''}');
  }
}
