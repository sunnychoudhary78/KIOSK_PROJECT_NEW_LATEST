import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';
import 'package:skp_kiosk/services/printer/printer_monitor.dart';

class PrinterHealthController extends Notifier<PrinterHealth> {
  Timer? _poll;
  Timer? _refreshWatch;
  bool _snmpPollerStarted = false;
  String? _lastRefreshAck;

  @override
  PrinterHealth build() {
    printerHeartbeatBodyBuilder = heartbeatPayload;
    ref.onDispose(() {
      _poll?.cancel();
      _refreshWatch?.cancel();
      if (_snmpPollerStarted) {
        unawaited(_monitor.stopSnmpPolling());
        _snmpPollerStarted = false;
      }
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
        _refreshWatch?.cancel();
        _refreshWatch = null;
        _lastRefreshAck = null;
        if (_snmpPollerStarted) {
          unawaited(_monitor.stopSnmpPolling());
          _snmpPollerStarted = false;
        }
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
    if (!_snmpPollerStarted) {
      _snmpPollerStarted = true;
      // Starts native cache; community is never logged or put in heartbeat.
      unawaited(_monitor.startSnmpPolling().then((ok) {
        if (!ok) {
          AppLogger.error('PRINTER SNMP poller failed to start');
          _snmpPollerStarted = false;
          return;
        }
        _armRefreshWatch();
      }));
    } else {
      _armRefreshWatch();
    }
    _poll ??= Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refresh());
    });
  }

  void _armRefreshWatch() {
    _refreshWatch ??= Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_publishPendingRefresh());
    });
  }

  Future<void> _publishPendingRefresh() async {
    final auth = ref.read(deviceAuthProvider);
    final deviceId = auth.deviceId;
    if (!auth.isAuthenticated || deviceId == null || deviceId.isEmpty) {
      return;
    }
    try {
      final result = await ref.read(apiClientProvider).get(
            '/devices/$deviceId/printer-refresh',
          );
      final requestedAt = result['requestedAt'] as String?;
      if (requestedAt == null || requestedAt.isEmpty || requestedAt == _lastRefreshAck) {
        return;
      }
      final fresh = await refresh();
      if (!fresh) return;
      final sent = await ref
          .read(deviceAuthProvider.notifier)
          .sendPrinterRefreshHeartbeat(requestedAt);
      if (sent) {
        _lastRefreshAck = requestedAt;
      }
    } catch (error) {
      AppLogger.error('PRINTER refresh publish failed', error);
    }
  }

  Future<bool> refresh() async {
    try {
      final health = await _monitor.getHealth();
      // Heartbeat uses toJson() which omits community / secrets.
      state = health;
      return true;
    } catch (error) {
      AppLogger.error('PRINTER health refresh failed', error);
      return false;
    }
  }

  Map<String, dynamic> heartbeatPayload() => state.toJson();
}

final printerHealthControllerProvider =
    NotifierProvider<PrinterHealthController, PrinterHealth>(
  PrinterHealthController.new,
);
