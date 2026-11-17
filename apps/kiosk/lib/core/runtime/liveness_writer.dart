import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/core/runtime/kiosk_runtime_paths.dart';

/// Writes a UTC ISO timestamp for the OS hang watchdog (`kiosk_watchdog.ps1`).
class LivenessWriter {
  LivenessWriter({
    this.path,
    this.interval = const Duration(seconds: 15),
    this.clock,
  });

  final String? path;
  final Duration interval;
  final DateTime Function()? clock;

  Timer? _timer;
  bool _started = false;
  bool _frameHooked = false;
  DateTime? _lastWriteAt;
  DateTime? _lastFrameAt;

  String get _path => path ?? kioskLivenessPath;

  DateTime? get lastWriteAt => _lastWriteAt;

  DateTime? get lastFrameAt => _lastFrameAt;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    unawaited(writeNow());
    _timer = Timer.periodic(interval, (_) => unawaited(writeNow()));
    if (!_frameHooked) {
      try {
        SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
        _frameHooked = true;
      } catch (_) {
        // Binding may be absent in pure unit tests; timer still updates the stamp.
      }
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  void _onFrame(Duration _) {
    _lastFrameAt = _now();
  }

  Future<void> writeNow() async {
    // Sync IO so a periodic timer cannot pile up awaits if the disk stalls briefly.
    try {
      final stamp = _now().toUtc().toIso8601String();
      final file = File(_path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(stamp, flush: true);
      _lastWriteAt = _now();
    } catch (error) {
      AppLogger.warn('liveness_write_failed path=$_path error=$error');
    }
  }

  DateTime _now() => clock?.call() ?? DateTime.now();
}

LivenessWriter? _sharedLivenessWriter;

LivenessWriter get sharedLivenessWriter =>
    _sharedLivenessWriter ??= LivenessWriter();

/// Test seam.
void debugResetSharedLivenessWriter([LivenessWriter? writer]) {
  _sharedLivenessWriter?.stop();
  _sharedLivenessWriter = writer;
}
