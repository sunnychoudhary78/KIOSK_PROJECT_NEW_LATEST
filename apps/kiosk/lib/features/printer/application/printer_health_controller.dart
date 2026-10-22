import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';
import 'package:skp_kiosk/services/printer/printer_monitor.dart';

class PrinterHealthController extends Notifier<PrinterHealth> {
  Timer? _poll;

  @override
  PrinterHealth build() {
    printerHeartbeatBodyBuilder = heartbeatPayload;
    ref.onDispose(() {
      _poll?.cancel();
      if (identical(printerHeartbeatBodyBuilder, heartbeatPayload)) {
        printerHeartbeatBodyBuilder = null;
      }
    });
    ref.listen(deviceAuthProvider, (_, next) {
      if (next.isAuthenticated) {
        _ensurePolling();
        unawaited(refresh());
      } else {
        _poll?.cancel();
        _poll = null;
      }
    });
    if (ref.read(deviceAuthProvider).isAuthenticated) {
      _ensurePolling();
      Future.microtask(refresh);
    }
    return PrinterHealth.unknown;
  }

  PrinterMonitor get _monitor => ref.read(printerMonitorProvider);

  void _ensurePolling() {
    _poll ??= Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    try {
      final health = await _monitor.getHealth();
      state = health;
    } catch (error) {
      AppLogger.error('PRINTER health refresh failed', error);
    }
  }

  Map<String, dynamic> heartbeatPayload() => state.toJson();
}

final printerHealthControllerProvider =
    NotifierProvider<PrinterHealthController, PrinterHealth>(
  PrinterHealthController.new,
);
