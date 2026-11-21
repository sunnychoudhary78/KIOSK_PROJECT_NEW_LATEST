import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/core/logging/diagnostic_categories.dart';
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
  String? _lastStatusSignature;
  bool _hadReportableMaintenance = false;
  bool _usbPublishInFlight = false;

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
    // Keep USB/local polling even while cloud auth is down. Ink/pages come from
    // HttpToUsbBridge on localhost; gating that on Wi-Fi left the admin card blank
    // after restart until someone reconnected the network.
    ref.listen(deviceAuthProvider, (previous, next) {
      _ensurePolling();
      if (next.isAuthenticated) {
        unawaited(refresh().then((_) => _publishMaintenanceIfNeeded(
              force: previous?.isAuthenticated != true,
            )));
      }
    });
    _ensurePolling();
    Future.microtask(() async {
      await refresh();
      await _publishMaintenanceIfNeeded(force: true);
    });
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
    try {
      final health = await _monitor.getHealth();
      final paper = health.noPaper || health.state == 'paper_out';
      if (!paper) _paperOutNotified = false;
      final changed = _overlaidHealthChanged(state, health);
      if (changed) {
        state = health;
        unawaited(_publishMaintenanceIfNeeded());
      }
      if (!paper || _paperOutNotified) return;
      if (!ref.read(deviceAuthProvider).isAuthenticated) return;
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
      _logStatusIfChanged(health);
      final changed = _overlaidHealthChanged(state, health);
      state = health;
      if (changed) {
        unawaited(_publishMaintenanceIfNeeded());
      }
      return true;
    } catch (error) {
      AppLogger.error('PRINTER health refresh failed', error);
      Diag.printerError(
        'printer.health_refresh_failed',
        'Printer health refresh failed',
        {'error': error.toString()},
      );
      return false;
    }
  }

  void _logStatusIfChanged(PrinterHealth health) {
    final signature = [
      health.state,
      health.online,
      health.noPaper,
      health.jammed,
      health.lastErrorCode,
      health.hrPrinterStatus,
    ].join('|');
    if (signature == _lastStatusSignature) return;
    _lastStatusSignature = signature;
    final levelError = health.isPhysicalFatal || health.noPaper || health.jammed;
    final meta = <String, dynamic>{
      'state': health.state,
      'online': health.online,
      'noPaper': health.noPaper,
      'jammed': health.jammed,
      if (health.lastErrorCode != null) 'lastErrorCode': health.lastErrorCode,
      if (health.hrPrinterStatus != null)
        'hrPrinterStatus': health.hrPrinterStatus,
      if (health.printerName != null) 'printerName': health.printerName,
    };
    if (levelError) {
      Diag.printerWarn('printer.status_changed', health.userMessage, meta);
    } else {
      Diag.printerInfo('printer.status_changed', 'Printer status updated', meta);
    }
  }

  Map<String, dynamic> heartbeatPayload() => state.toJson();

  /// Push ink/pages to the API as soon as USB has them (or after re-auth).
  Future<void> _publishMaintenanceIfNeeded({bool force = false}) async {
    if (!ref.read(deviceAuthProvider).isAuthenticated) return;
    if (!_hasReportableMaintenance(state)) return;
    final firstReport = !_hadReportableMaintenance;
    if (!force && !firstReport) return;
    if (_usbPublishInFlight) return;
    _usbPublishInFlight = true;
    try {
      final sent =
          await ref.read(deviceAuthProvider.notifier).sendPrinterHealthHeartbeat();
      if (sent) {
        _hadReportableMaintenance = true;
        AppLogger.info(
          'PRINTER maintenance heartbeat sent'
          '${firstReport ? ' (first USB sample)' : force ? ' (auth recovered)' : ''}',
        );
      }
    } catch (error) {
      AppLogger.error('PRINTER maintenance heartbeat failed', error);
    } finally {
      _usbPublishInFlight = false;
    }
  }

  /// USB latch for ink/pages. Runs without cloud auth so values are ready when
  /// the network comes back after boot or an app update.
  Future<void> _compareUsb() async {
    final watch = ref.read(usbPageWatchProvider);
    if (watch.suppress || _usbCompareBusy) {
      return;
    }
    _usbCompareBusy = true;
    final jobLocked = ref.read(printCoordinatorProvider).isLocked;
    final full = !jobLocked &&
        (_nextFullUsbAt == null || !DateTime.now().isBefore(_nextFullUsbAt!));
    try {
      final hadUsb = watch.lastUsbOk == true;
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
      if (snapshot.ok) {
        final health = await _monitor.getHealth();
        if (_overlaidHealthChanged(state, health)) {
          state = health;
        }
        // First success or recovery after bridge/USB failures — do not wait for
        // the 1-minute keepalive before admin shows ink/pages.
        if (!hadUsb) {
          unawaited(_publishMaintenanceIfNeeded(force: true));
        }
      }
    } catch (error) {
      AppLogger.error('PRINTER usb-compare failed', error);
    } finally {
      _usbCompareBusy = false;
    }
  }
}

bool _hasReportableMaintenance(PrinterHealth health) {
  final maintenance = health.maintenance;
  if (maintenance == null || maintenance.available != true) return false;
  final toner = maintenance.toner;
  final pages = maintenance.pages;
  return toner?.blackPercent != null ||
      toner?.cyanPercent != null ||
      toner?.magentaPercent != null ||
      toner?.yellowPercent != null ||
      pages?.total != null;
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
