import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';

const printerMethodChannel = MethodChannel('skp/printer');

abstract class PrinterNative {
  Future<bool> configureSnmpPolling({
    required String host,
    required String community,
    int intervalMs = 2000,
    int timeoutMs = 3000,
  });

  Future<void> stopSnmpPolling();

  Future<PrinterHealth> getHealth({
    required String printerName,
    required String snmpHost,
    required String snmpCommunity,
    required String model,
  });

  Future<int?> getPageCounter({
    required String snmpHost,
    required String snmpCommunity,
  });

  Future<PrinterHealth> getPrinterStatus({required String printerName});
}

class MethodChannelPrinterNative implements PrinterNative {
  MethodChannelPrinterNative({MethodChannel? methods})
      : _methods = methods ?? printerMethodChannel;

  final MethodChannel _methods;

  @override
  Future<bool> configureSnmpPolling({
    required String host,
    required String community,
    int intervalMs = 2000,
    int timeoutMs = 3000,
  }) async {
    try {
      final raw = await _methods.invokeMethod<dynamic>('configureSnmpPolling', {
        'host': host,
        'community': community,
        'intervalMs': intervalMs,
        'timeoutMs': timeoutMs,
      });
      if (raw is Map) {
        return raw['ok'] == true;
      }
      return false;
    } on MissingPluginException {
      AppLogger.error('PRINTER native plugin missing for configureSnmpPolling');
      return false;
    } catch (error) {
      AppLogger.error('PRINTER configureSnmpPolling failed', error);
      return false;
    }
  }

  @override
  Future<void> stopSnmpPolling() async {
    try {
      await _methods.invokeMethod<dynamic>('stopSnmpPolling');
    } on MissingPluginException {
      // ignore
    } catch (error) {
      AppLogger.error('PRINTER stopSnmpPolling failed', error);
    }
  }

  @override
  Future<PrinterHealth> getHealth({
    required String printerName,
    required String snmpHost,
    required String snmpCommunity,
    required String model,
  }) async {
    try {
      final raw = await _methods.invokeMethod<dynamic>('getHealth', {
        'printerName': printerName,
        'snmpHost': snmpHost,
        'snmpCommunity': snmpCommunity,
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
  Future<int?> getPageCounter({
    required String snmpHost,
    required String snmpCommunity,
  }) async {
    try {
      final raw = await _methods.invokeMethod<dynamic>('getPageCounter', {
        'snmpHost': snmpHost,
        'snmpCommunity': snmpCommunity,
      });
      if (raw is Map && raw['ok'] == true) {
        return (raw['pageCounter'] as num?)?.toInt();
      }
      return null;
    } on MissingPluginException {
      AppLogger.error('PRINTER native plugin missing for getPageCounter');
      return null;
    } catch (error) {
      AppLogger.error('PRINTER getPageCounter failed', error);
      return null;
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
}

/// In-memory fake for unit tests.
class FakePrinterNative implements PrinterNative {
  FakePrinterNative({
    this.health = PrinterHealth.unknown,
    this.pageCounter,
    this.pageCounterSequence,
  });

  PrinterHealth health;
  int? pageCounter;
  /// Optional sequence of counter reads (null entries = SNMP miss).
  List<int?>? pageCounterSequence;
  int _counterIndex = 0;
  bool snmpPollingConfigured = false;

  @override
  Future<bool> configureSnmpPolling({
    required String host,
    required String community,
    int intervalMs = 2000,
    int timeoutMs = 3000,
  }) async {
    snmpPollingConfigured = host.isNotEmpty && community.isNotEmpty;
    return snmpPollingConfigured;
  }

  @override
  Future<void> stopSnmpPolling() async {
    snmpPollingConfigured = false;
  }

  @override
  Future<PrinterHealth> getHealth({
    required String printerName,
    required String snmpHost,
    required String snmpCommunity,
    required String model,
  }) async {
    final counter = await getPageCounter(
      snmpHost: snmpHost,
      snmpCommunity: snmpCommunity,
    );
    return PrinterHealth(
      state: health.state,
      online: health.online,
      printerName: health.printerName ?? printerName,
      model: model,
      trays: health.trays,
      supplies: health.supplies,
      pageCounter: counter ?? health.pageCounter,
      snmpOk: counter != null || health.snmpOk == true,
      snmpReachable: health.snmpReachable ?? (counter != null),
      snmpConfigured: health.snmpConfigured ?? snmpPollingConfigured,
      consecutiveFailures: health.consecutiveFailures,
      lastSuccessAtMs: health.lastSuccessAtMs,
      lastPollError: health.lastPollError,
      hrPrinterStatus: health.hrPrinterStatus,
      hrPrinterStatusLabel: health.hrPrinterStatusLabel,
      errorFlagsHex: health.errorFlagsHex,
      noPaper: health.noPaper,
      jammed: health.jammed,
      offlineBit: health.offlineBit,
      lowPaper: health.lowPaper,
      lowToner: health.lowToner,
      noToner: health.noToner,
      doorOpen: health.doorOpen,
      spoolerJobsQueued: health.spoolerJobsQueued,
      spoolerJobsPrinting: health.spoolerJobsPrinting,
      lastErrorCode: health.lastErrorCode,
    );
  }

  @override
  Future<int?> getPageCounter({
    required String snmpHost,
    required String snmpCommunity,
  }) async {
    final seq = pageCounterSequence;
    if (seq != null && seq.isNotEmpty) {
      final value = seq[_counterIndex.clamp(0, seq.length - 1)];
      if (_counterIndex < seq.length - 1) {
        _counterIndex++;
      }
      return value;
    }
    return pageCounter;
  }

  @override
  Future<PrinterHealth> getPrinterStatus({required String printerName}) async {
    return health;
  }
}
