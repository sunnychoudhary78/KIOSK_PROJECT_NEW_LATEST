import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';
import 'package:skp_kiosk/services/printer/printer_monitor.dart';
import 'package:skp_kiosk/services/printer/usb_page_watch.dart';
import 'package:skp_kiosk/services/printer/usb_snapshot.dart';

class PrinterHealthController extends Notifier<PrinterHealth> {
  Timer? _poll;
  Timer? _refreshWatch;
  String? _lastRefreshAck;
  bool _paperOutNotified = false;
  bool _usbCompareBusy = false;
  DateTime? _nextFullUsbAt;
  int? _previousUsbPages;
  int? _lastUsbStatusCode;

  @override
  PrinterHealth build() {
    printerHeartbeatBodyBuilder = heartbeatPayload;
    ref.onDispose(() {
      _poll?.cancel();
      _refreshWatch?.cancel();
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
        _previousUsbPages = null;
        _lastUsbStatusCode = null;
        _nextFullUsbAt = null;
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
    _armRefreshWatch();
    _poll ??= Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refresh());
    });
  }

  void _armRefreshWatch() {
    _refreshWatch ??= Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_publishPendingRefresh());
      unawaited(_watchPaperOut());
      unawaited(_compareUsb());
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

  Future<void> _watchPaperOut() async {
    if (!ref.read(deviceAuthProvider).isAuthenticated) return;
    try {
      final health = await _monitor.getHealth();
      final paper = health.noPaper || health.state == 'paper_out';
      if (!paper) _paperOutNotified = false;
      if (_overlaidHealthChanged(state, health)) {
        state = health;
      }
      if (!paper || _paperOutNotified) return;
      final sent = await ref.read(deviceAuthProvider.notifier).sendPrinterHealthHeartbeat();
      if (sent) _paperOutNotified = true;
    } catch (error) {
      AppLogger.error('PRINTER paper-out watch failed', error);
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

  /// Logs USB readings. Does not change [state] or the heartbeat.
  Future<void> _compareUsb() async {
    final watch = ref.read(usbPageWatchProvider);
    if (watch.suppress ||
        _usbCompareBusy ||
        !ref.read(deviceAuthProvider).isAuthenticated) {
      return;
    }
    _usbCompareBusy = true;
    final jobLocked = ref.read(printCoordinatorProvider).isLocked;
    final full = !jobLocked &&
        (_nextFullUsbAt == null || !DateTime.now().isBefore(_nextFullUsbAt!));
    try {
      final snapshot = await _monitor.getUsbSnapshot(full: full);
      watch.record(snapshot);
      final statusCode = watch.statusCode;
      if (snapshot.ok && statusCode != null && statusCode != _lastUsbStatusCode) {
        _lastUsbStatusCode = statusCode;
        AppLogger.info(
          formatUsbStatusLine(
            code: statusCode,
            message: watch.statusMessage,
          ),
        );
      }
      if (full && snapshot.ok) {
        _nextFullUsbAt = DateTime.now().add(const Duration(minutes: 1));
      }
      AppLogger.info(
        formatUsbCompareLine(
          previousUsbPages: _previousUsbPages,
          snapshot: snapshot,
          tonerBlack: watch.tonerBlack,
          tonerCyan: watch.tonerCyan,
          tonerMagenta: watch.tonerMagenta,
          tonerYellow: watch.tonerYellow,
        ),
      );
      if (snapshot.ok && snapshot.pagesTotal != null) {
        _previousUsbPages = snapshot.pagesTotal;
      }
    } catch (error) {
      AppLogger.error('PRINTER usb-compare failed', error);
    } finally {
      _usbCompareBusy = false;
    }
  }
}

bool _overlaidHealthChanged(PrinterHealth current, PrinterHealth next) {
  return current.state != next.state ||
      current.noPaper != next.noPaper ||
      current.online != next.online ||
      current.snmpOk != next.snmpOk ||
      current.snmpReachable != next.snmpReachable ||
      current.lastSuccessAtMs != next.lastSuccessAtMs ||
      current.maintenance?.toJson().toString() !=
          next.maintenance?.toJson().toString() ||
      current.errorHistory?.toJson().toString() !=
          next.errorHistory?.toJson().toString();
}

final printerHealthControllerProvider =
    NotifierProvider<PrinterHealthController, PrinterHealth>(
  PrinterHealthController.new,
);
