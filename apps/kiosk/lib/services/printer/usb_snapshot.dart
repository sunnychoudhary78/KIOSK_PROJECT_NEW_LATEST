import 'dart:convert';

import 'package:skp_kiosk/services/printer/printer_health.dart';

class UsbSnapshot {
  const UsbSnapshot({
    required this.ok,
    this.connected = false,
    this.error,
    this.statusCode,
    this.statusMessage,
    this.statusType,
    this.tonerBlack,
    this.tonerCyan,
    this.tonerMagenta,
    this.tonerYellow,
    this.pagesTotal,
    this.pagesColor,
    this.pagesBlackAndWhite,
    this.pagesDuplexTotal,
    this.pagesDuplexColor,
    this.pagesDuplexBlackAndWhite,
    this.refillBlack,
    this.refillCyan,
    this.refillMagenta,
    this.refillYellow,
    this.beltRemainingPages,
    this.fuserRemainingPages,
    this.firmwareMain,
    this.firmwareSub3,
    this.model,
    this.serialNumber,
    this.errorHistory,
  });

  final bool ok;
  final bool connected;
  final String? error;
  final int? statusCode;
  final String? statusMessage;
  final String? statusType;
  final int? tonerBlack;
  final int? tonerCyan;
  final int? tonerMagenta;
  final int? tonerYellow;
  final int? pagesTotal;
  final int? pagesColor;
  final int? pagesBlackAndWhite;
  final int? pagesDuplexTotal;
  final int? pagesDuplexColor;
  final int? pagesDuplexBlackAndWhite;
  final int? refillBlack;
  final int? refillCyan;
  final int? refillMagenta;
  final int? refillYellow;
  final int? beltRemainingPages;
  final int? fuserRemainingPages;
  final String? firmwareMain;
  final String? firmwareSub3;
  final String? model;
  final String? serialNumber;

  /// Null when this snapshot did not read history. An empty list is a full read
  /// that found no descriptions.
  final List<PrinterErrorHistoryEntry>? errorHistory;

  factory UsbSnapshot.failed(String error) {
    return UsbSnapshot(ok: false, error: error);
  }

  factory UsbSnapshot.fromJson(Map<String, dynamic> json) {
    return UsbSnapshot(
      ok: json['ok'] == true,
      connected: json['connected'] == true,
      error: json['error'] as String?,
      statusCode: (json['statusCode'] as num?)?.toInt(),
      statusMessage: json['statusMessage'] as String?,
      statusType: json['statusType'] as String?,
      tonerBlack: (json['tonerBlack'] as num?)?.toInt(),
      tonerCyan: (json['tonerCyan'] as num?)?.toInt(),
      tonerMagenta: (json['tonerMagenta'] as num?)?.toInt(),
      tonerYellow: (json['tonerYellow'] as num?)?.toInt(),
      pagesTotal: (json['pagesTotal'] as num?)?.toInt(),
      pagesColor: (json['pagesColor'] as num?)?.toInt(),
      pagesBlackAndWhite: (json['pagesBlackAndWhite'] as num?)?.toInt(),
      pagesDuplexTotal: (json['pagesDuplexTotal'] as num?)?.toInt(),
      pagesDuplexColor: (json['pagesDuplexColor'] as num?)?.toInt(),
      pagesDuplexBlackAndWhite:
          (json['pagesDuplexBlackAndWhite'] as num?)?.toInt(),
      refillBlack: (json['refillBlack'] as num?)?.toInt(),
      refillCyan: (json['refillCyan'] as num?)?.toInt(),
      refillMagenta: (json['refillMagenta'] as num?)?.toInt(),
      refillYellow: (json['refillYellow'] as num?)?.toInt(),
      beltRemainingPages: (json['beltRemainingPages'] as num?)?.toInt(),
      fuserRemainingPages: (json['fuserRemainingPages'] as num?)?.toInt(),
      firmwareMain: json['firmwareMain'] as String?,
      firmwareSub3: json['firmwareSub3'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serialNumber'] as String?,
      errorHistory: json.containsKey('errorHistory')
          ? usbErrorHistoryEntries(json['errorHistory'])
          : null,
    );
  }

  static UsbSnapshot parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return UsbSnapshot.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Fall through to a failed snapshot.
    }
    return UsbSnapshot.failed('usb_helper_failed');
  }
}

/// Lab-confirmed Brother status codes mapped from EWS monitor text. Anything else is unmapped.
const int usbStatusSleep = 40000;
const int usbStatusReady = 10001;
const int usbStatusWait = 10003;
const int usbStatusPrinting = 10023;
const int usbStatusPaperOut = 41236;

String usbStatusKind(int? code) {
  switch (code) {
    case usbStatusSleep:
      return 'sleep';
    case usbStatusReady:
      return 'ready';
    case usbStatusWait:
      return 'wait';
    case usbStatusPrinting:
      return 'printing';
    case usbStatusPaperOut:
      return 'paper_out';
    default:
      return 'unmapped';
  }
}

/// Logged once when the USB status code changes. Does not change printer state.
String formatUsbStatusLine({
  required int code,
  String? message,
}) {
  return 'PRINTER usb-status code=$code message=${message ?? ''} kind=${usbStatusKind(code)}';
}

/// USB telemetry never replaces the SNMP heartbeat.
PrinterHealth healthAfterUsbRead(PrinterHealth health, UsbSnapshot snapshot) {
  return healthAfterUsbStatus(health, snapshot.statusCode);
}

/// Descriptions from a full USB history, stored as indexes 1 through 10.
List<PrinterErrorHistoryEntry> usbErrorHistoryEntries(Object? raw) {
  if (raw is! List) return const [];
  final entries = <PrinterErrorHistoryEntry>[];
  for (final item in raw) {
    if (entries.length >= 10) break;
    if (item is! Map) continue;
    final description = (item['description'] as String?)?.trim() ?? '';
    if (description.isEmpty) continue;
    final text = description.length > 160 ? description.substring(0, 160) : description;
    entries.add(PrinterErrorHistoryEntry(index: entries.length + 1, description: text));
  }
  return entries;
}

/// Printing and wait become `printing`. Ready and sleep become `ready`.
/// An unmapped code leaves [health.state] unchanged. Online is unchanged.
PrinterHealth healthAfterUsbActivity(PrinterHealth health, int? statusCode) {
  switch (usbStatusKind(statusCode)) {
    case 'printing':
    case 'wait':
      return health.withActivityState('printing');
    case 'ready':
    case 'sleep':
      return health.withActivityState('ready');
    default:
      return health;
  }
}

/// `41236` latches tray 1 paper-out. An unmapped code does not set noPaper.
PrinterHealth healthAfterUsbStatus(
  PrinterHealth health,
  int? statusCode, {
  bool paperOutLatched = false,
}) {
  final paper = paperOutLatched || usbStatusKind(statusCode) == 'paper_out';
  if (!paper) return health;
  return health.withPaperOut();
}

/// USB readings since the previous successful sample.
String formatUsbCompareLine({
  required int? previousUsbPages,
  required UsbSnapshot snapshot,
  int? tonerBlack,
  int? tonerCyan,
  int? tonerMagenta,
  int? tonerYellow,
}) {
  final parts = <String>['PRINTER usb-compare'];
  void add(String key, Object? value) {
    if (value == null) return;
    parts.add('$key=$value');
  }

  add('pagesTotalUsb', snapshot.pagesTotal);
  if (snapshot.pagesTotal != null && previousUsbPages != null) {
    add('deltaUsb', snapshot.pagesTotal! - previousUsbPages);
  }
  add('statusCode', snapshot.statusCode);
  add('statusMessage', snapshot.statusMessage);
  add('tonerBlack', snapshot.tonerBlack ?? tonerBlack);
  add('tonerCyan', snapshot.tonerCyan ?? tonerCyan);
  add('tonerMagenta', snapshot.tonerMagenta ?? tonerMagenta);
  add('tonerYellow', snapshot.tonerYellow ?? tonerYellow);
  add('belt', snapshot.beltRemainingPages);
  add('usbError', snapshot.error);
  return parts.join(' ');
}
