import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';

const printerMethodChannel = MethodChannel('skp/printer');

abstract class PrinterNative {
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

  Map<String, Object?> _snmpArgs({
    required String printerName,
    required String snmpHost,
    required String snmpCommunity,
    required String model,
  }) =>
      {
        'printerName': printerName,
        'snmpHost': snmpHost,
        'snmpCommunity': snmpCommunity,
        'model': model,
      };

  @override
  Future<PrinterHealth> getHealth({
    required String printerName,
    required String snmpHost,
    required String snmpCommunity,
    required String model,
  }) async {
    try {
      final raw = await _methods.invokeMethod<dynamic>(
        'getHealth',
        _snmpArgs(
          printerName: printerName,
          snmpHost: snmpHost,
          snmpCommunity: snmpCommunity,
          model: model,
        ),
      );
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
