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
    bool forceRefresh = false,
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
    bool forceRefresh = false,
  }) async {
    try {
      final raw = await _methods.invokeMethod<dynamic>('getPageCounter', {
        'snmpHost': snmpHost,
        'snmpCommunity': snmpCommunity,
        'forceRefresh': forceRefresh,
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
    this.healthAfterFirst,
  });

  PrinterHealth health;
  /// Returned from the 2nd getHealth call onward (mid-reconcile blips).
  PrinterHealth? healthAfterFirst;
  int? pageCounter;
  /// Optional sequence of counter reads (null entries = SNMP miss).
  List<int?>? pageCounterSequence;
  int _counterIndex = 0;
  int _healthReads = 0;
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
    _healthReads++;
    final source = (_healthReads > 1 && healthAfterFirst != null)
        ? healthAfterFirst!
        : health;
    // Do not consume pageCounterSequence — reconcile uses getPageCounter.
    return PrinterHealth(
      state: source.state,
      online: source.online,
      printerName: source.printerName ?? printerName,
      model: model,
      trays: source.trays,
      supplies: source.supplies,
      pageCounter: source.pageCounter ?? pageCounter,
      snmpOk: source.snmpOk ?? (pageCounter != null),
      snmpReachable: source.snmpReachable ?? true,
      snmpConfigured: source.snmpConfigured ?? snmpPollingConfigured,
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
  Future<int?> getPageCounter({
    required String snmpHost,
    required String snmpCommunity,
    bool forceRefresh = false,
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
