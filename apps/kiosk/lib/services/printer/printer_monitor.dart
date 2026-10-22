import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';
import 'package:skp_kiosk/services/printer/printer_native.dart';

final printerNativeProvider = Provider<PrinterNative>((ref) {
  return MethodChannelPrinterNative();
});

final printerMonitorProvider = Provider<PrinterMonitor>((ref) {
  return PrinterMonitor(
    native: ref.watch(printerNativeProvider),
    config: AppConfig.fromEnvironment(),
  );
});

class PrinterMonitor {
  PrinterMonitor({
    required PrinterNative native,
    required AppConfig config,
  })  : _native = native,
        _config = config;

  final PrinterNative _native;
  final AppConfig _config;

  bool get snmpConfigured => _config.snmpConfigured;

  int get reconcileTimeoutMs => _config.printReconcileTimeoutMs;

  Future<PrinterHealth> getHealth() {
    return _native.getHealth(
      printerName: _config.printerName,
      snmpHost: _config.printerSnmpHost,
      snmpCommunity: _config.printerSnmpCommunity,
      model: _config.printerModel,
    );
  }

  Future<int?> getPageCounter() {
    if (!_config.snmpConfigured) {
      return Future.value(null);
    }
    return _native.getPageCounter(
      snmpHost: _config.printerSnmpHost,
      snmpCommunity: _config.printerSnmpCommunity,
    );
  }

  Future<PrinterHealth> getSpoolerStatus() {
    return _native.getPrinterStatus(printerName: _config.printerName);
  }
}
