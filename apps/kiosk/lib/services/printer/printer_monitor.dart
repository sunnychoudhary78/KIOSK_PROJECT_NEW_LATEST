import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';
import 'package:skp_kiosk/services/printer/printer_native.dart';
import 'package:skp_kiosk/services/printer/usb_page_watch.dart';
import 'package:skp_kiosk/services/printer/usb_snapshot.dart';

final printerNativeProvider = Provider<PrinterNative>((ref) {
  return MethodChannelPrinterNative();
});

final printerMonitorProvider = Provider<PrinterMonitor>((ref) {
  return PrinterMonitor(
    native: ref.watch(printerNativeProvider),
    config: AppConfig.fromEnvironment(),
    usbPageWatch: ref.watch(usbPageWatchProvider),
  );
});

class PrinterMonitor {
  PrinterMonitor({
    required PrinterNative native,
    required AppConfig config,
    UsbPageWatch? usbPageWatch,
  })  : _native = native,
        _config = config,
        _usbPageWatch = usbPageWatch;

  final PrinterNative _native;
  final AppConfig _config;
  final UsbPageWatch? _usbPageWatch;

  int get reconcileTimeoutMs => _config.printReconcileTimeoutMs;

  Future<PrinterHealth> getHealth() async {
    final health = await _native.getHealth(
      printerName: _config.printerName,
      model: _config.printerModel,
    );
    final watch = _usbPageWatch;
    if (watch == null || watch.lastUsbOk == null) return health;
    final activity = healthAfterUsbActivity(health, watch.statusCode);
    final paperLatched = watch.paperOutLatched ||
        usbStatusKind(watch.statusCode) == 'paper_out';
    final paper = paperLatched
        ? healthAfterUsbStatus(
            activity,
            watch.statusCode,
            paperOutLatched: watch.paperOutLatched,
          )
        : activity.withoutSnmpFaultFlags();
    final details = paper.withUsbMaintenance(
      blackPercent: watch.tonerBlack,
      cyanPercent: watch.tonerCyan,
      magentaPercent: watch.tonerMagenta,
      yellowPercent: watch.tonerYellow,
      pagesTotal: watch.latestPages,
      pagesColor: watch.pagesColor,
      pagesBlackAndWhite: watch.pagesBlackAndWhite,
      beltRemainingPages: watch.beltRemainingPages,
      fuserRemainingPages: watch.fuserRemainingPages,
    );
    final history = watch.errorHistoryRead
        ? details.withUsbErrorHistory(watch.errorHistory)
        : details.withoutErrorHistory();
    final lastSuccessAt = watch.lastUsbSuccessAt;
    if (lastSuccessAt == null) return history;
    return history.withUsbFreshness(
      lastReadOk: watch.lastUsbOk!,
      lastSuccessAt: lastSuccessAt,
    );
  }

  Future<PrinterHealth> getSpoolerStatus() {
    return _native.getPrinterStatus(printerName: _config.printerName);
  }

  Future<UsbSnapshot> getUsbSnapshot({required bool full}) {
    return _native.getUsbSnapshot(scope: full ? 'full' : 'fast');
  }
}
