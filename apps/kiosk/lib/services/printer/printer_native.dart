import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';
import 'package:skp_kiosk/services/printer/usb_snapshot.dart';

const printerMethodChannel = MethodChannel('skp/printer');

/// USB queue chosen by the native spooler. [name] is the Windows printer name.
class UsbPrinterResolution {
  const UsbPrinterResolution({
    required this.found,
    this.name = '',
    this.port = '',
  });

  final bool found;
  final String name;
  final String port;
}

abstract class PrinterNative {
  Future<PrinterHealth> getHealth({
    required String printerName,
    required String model,
  });

  Future<PrinterHealth> getPrinterStatus({required String printerName});

  Future<UsbPrinterResolution> resolveUsbPrinter({required String printerName});

  Future<UsbSnapshot> getUsbSnapshot({required String scope});
}

class MethodChannelPrinterNative implements PrinterNative {
  MethodChannelPrinterNative({MethodChannel? methods})
      : _methods = methods ?? printerMethodChannel;

  final MethodChannel _methods;

  @override
  Future<PrinterHealth> getHealth({
    required String printerName,
    required String model,
  }) async {
    try {
      final raw = await _methods.invokeMethod<dynamic>('getHealth', {
        'printerName': printerName,
        'model': model,
      });
      if (raw is Map) {
        return PrinterHealth.fromJson(raw);
      }
      return PrinterHealth.unknown;
    } on MissingPluginException {
      AppLogger.error('PRINTER native plugin missing for getHealth');
      return PrinterHealth.unknown;
    } catch (error) {
      AppLogger.error('PRINTER getHealth failed', error);
      return PrinterHealth.unknown;
    }
  }

  @override
  Future<PrinterHealth> getPrinterStatus({required String printerName}) async {
    try {
      final raw = await _methods.invokeMethod<dynamic>('getPrinterStatus', {
        'printerName': printerName,
      });
      if (raw is Map) {
        return PrinterHealth(
          state: raw['state'] as String? ?? 'unknown',
          online: raw['online'] as bool? ?? false,
          printerName: raw['name'] as String?,
          lastErrorCode: raw['lastErrorCode'] as String?,
          spoolerJobsQueued: (raw['jobsQueued'] as num?)?.toInt(),
          spoolerJobsPrinting: (raw['jobsPrinting'] as num?)?.toInt(),
          spoolerLatestJobId: (raw['latestJobId'] as num?)?.toInt(),
          spoolerLatestJobStatus: raw['latestJobStatus'] as String?,
        );
      }
      return PrinterHealth.unknown;
    } on MissingPluginException {
      return PrinterHealth.unknown;
    } catch (error, stack) {
      debugPrint('PRINTER getPrinterStatus failed: $error\n$stack');
      return PrinterHealth.unknown;
    }
  }

  @override
  Future<UsbPrinterResolution> resolveUsbPrinter({
    required String printerName,
  }) async {
    try {
      final raw = await _methods.invokeMethod<dynamic>('resolveUsbPrinter', {
        'printerName': printerName,
      });
      if (raw is Map) {
        return UsbPrinterResolution(
          found: raw['found'] == true,
          name: raw['name'] as String? ?? '',
          port: raw['port'] as String? ?? '',
        );
      }
      return const UsbPrinterResolution(found: false);
    } on MissingPluginException {
      AppLogger.error('PRINTER native plugin missing for resolveUsbPrinter');
      return const UsbPrinterResolution(found: false);
    } catch (error) {
      AppLogger.error('PRINTER resolveUsbPrinter failed', error);
      return const UsbPrinterResolution(found: false);
    }
  }

  @override
  Future<UsbSnapshot> getUsbSnapshot({required String scope}) async {
    try {
      final raw = await _methods.invokeMethod<dynamic>('getUsbSnapshot', {
        'scope': scope,
      });
      if (raw is String && raw.isNotEmpty) {
        return UsbSnapshot.parse(raw);
      }
      if (raw is Map) {
        return UsbSnapshot.fromJson(Map<String, dynamic>.from(raw));
      }
      return UsbSnapshot.failed('usb_helper_failed');
    } on MissingPluginException {
      AppLogger.error('PRINTER native plugin missing for getUsbSnapshot');
      return UsbSnapshot.failed('helper_missing');
    } catch (error) {
      AppLogger.error('PRINTER getUsbSnapshot failed', error);
      return UsbSnapshot.failed('usb_helper_failed');
    }
  }
}

/// In-memory fake for unit tests.
class FakePrinterNative implements PrinterNative {
  FakePrinterNative({
    this.health = PrinterHealth.unknown,
    this.usbPagesSequence,
    this.healthAfterFirst,
  });

  PrinterHealth health;
  /// Returned from the 2nd getHealth call onward (mid-reconcile blips).
  PrinterHealth? healthAfterFirst;
  /// Optional USB total sequence. Null entries are failed reads (`usb_timeout`).
  List<int?>? usbPagesSequence;
  int _usbIndex = 0;
  int usbSnapshotCalls = 0;
  int _healthReads = 0;
  UsbPrinterResolution usbPrinter = const UsbPrinterResolution(
    found: true,
    name: 'Brother HL-L3280CDW series',
    port: 'USB001',
  );
  UsbSnapshot usbSnapshot = UsbSnapshot.failed('helper_missing');

  @override
  Future<PrinterHealth> getHealth({
    required String printerName,
    required String model,
  }) async {
    _healthReads++;
    final source = (_healthReads > 1 && healthAfterFirst != null)
        ? healthAfterFirst!
        : health;
    return PrinterHealth(
      state: source.state,
      online: source.online,
      printerName: source.printerName ?? printerName,
      model: model,
      trays: source.trays,
      supplies: source.supplies,
      maintenance: source.maintenance,
      errorHistory: source.errorHistory,
      pageCounter: source.pageCounter,
      snmpOk: source.snmpOk,
      snmpReachable: source.snmpReachable,
      snmpConfigured: source.snmpConfigured,
      consecutiveFailures: source.consecutiveFailures,
      lastSuccessAtMs: source.lastSuccessAtMs,
      lastPollError: source.lastPollError,
      hrPrinterStatus: source.hrPrinterStatus,
      hrPrinterStatusLabel: source.hrPrinterStatusLabel,
      errorFlagsHex: source.errorFlagsHex,
      noPaper: source.noPaper,
      jammed: source.jammed,
      offlineBit: source.offlineBit,
      lowPaper: source.lowPaper,
      lowToner: source.lowToner,
      noToner: source.noToner,
      doorOpen: source.doorOpen,
      spoolerJobsQueued: source.spoolerJobsQueued,
      spoolerJobsPrinting: source.spoolerJobsPrinting,
      lastErrorCode: source.lastErrorCode,
    );
  }

  @override
  Future<PrinterHealth> getPrinterStatus({required String printerName}) async {
    return health;
  }

  @override
  Future<UsbPrinterResolution> resolveUsbPrinter({
    required String printerName,
  }) async {
    return usbPrinter;
  }

  @override
  Future<UsbSnapshot> getUsbSnapshot({required String scope}) async {
    usbSnapshotCalls++;
    final seq = usbPagesSequence;
    if (seq != null && seq.isNotEmpty) {
      final value = seq[_usbIndex.clamp(0, seq.length - 1)];
      if (_usbIndex < seq.length - 1) {
        _usbIndex++;
      }
      if (value == null) {
        return UsbSnapshot.failed('usb_timeout');
      }
      return UsbSnapshot(ok: true, connected: true, pagesTotal: value);
    }
    return usbSnapshot;
  }
}
