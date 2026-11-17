import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';

/// Last-resort recovery when the UI isolate stops producing frames.
///
/// Calls [exit] so `kiosk_shell.bat` can relaunch. Gated to Windows release
/// builds by default; override with `--dart-define=SKP_ENABLE_UI_WATCHDOG=true|false`.
class UiHangWatchdog {
  UiHangWatchdog({
    this.noFrameLimit = const Duration(seconds: 45),
    this.pollInterval = const Duration(seconds: 5),
    this.clock,
    this.onHang,
    this.enabledOverride,
  });

  final Duration noFrameLimit;
  final Duration pollInterval;
  final DateTime Function()? clock;
  final void Function()? onHang;
  final bool? enabledOverride;

  Timer? _timer;
  DateTime? _lastFrameAt;
  bool _started = false;
  bool _frameHooked = false;
  bool _triggered = false;

  static bool resolveEnabled({bool? override}) {
    if (override != null) {
      return override;
    }
    const raw = String.fromEnvironment(
      'SKP_ENABLE_UI_WATCHDOG',
      defaultValue: '',
    );
    final normalized = raw.toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
    return !kDebugMode && Platform.isWindows;
  }

  bool get isEnabled => resolveEnabled(override: enabledOverride);

  void start() {
    if (_started || !isEnabled) {
      return;
    }
    _started = true;
    _lastFrameAt = _now();
    if (!_frameHooked) {
      try {
        SchedulerBinding.instance.addPersistentFrameCallback((_) {
          _lastFrameAt = _now();
        });
        _frameHooked = true;
      } catch (_) {
        // Binding may be absent in pure unit tests; clock-driven checks still run.
      }
    }
    _timer = Timer.periodic(pollInterval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  void _check() {
    if (_triggered || !isEnabled) {
      return;
    }
    final last = _lastFrameAt;
    if (last == null) {
      return;
    }
    final age = _now().difference(last);
    if (age < noFrameLimit) {
      return;
    }
    _triggered = true;
    AppLogger.error(
      'ui_hang_watchdog_exit noFrameMs=${age.inMilliseconds}',
    );
    final handler = onHang;
    if (handler != null) {
      handler();
      return;
    }
    exit(1);
  }

  DateTime _now() => clock?.call() ?? DateTime.now();
}

UiHangWatchdog? _sharedUiHangWatchdog;

UiHangWatchdog get sharedUiHangWatchdog =>
    _sharedUiHangWatchdog ??= UiHangWatchdog();

void debugResetSharedUiHangWatchdog([UiHangWatchdog? watchdog]) {
  _sharedUiHangWatchdog?.stop();
  _sharedUiHangWatchdog = watchdog;
}
