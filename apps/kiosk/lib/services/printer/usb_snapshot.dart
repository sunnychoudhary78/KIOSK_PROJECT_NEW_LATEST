import 'dart:convert';
import 'dart:typed_data';

import 'package:skp_kiosk/services/printer/printer_health.dart';

/// Known Brother USB record ids. Unknown ids are listed and not named.
class BrotherUsbRecords {
  const BrotherUsbRecords({
    this.pagesTotal,
    this.pagesColor,
    this.pagesBlackAndWhite,
    this.beltRemainingPages,
    this.fuserRemainingPages,
    this.tonerBlack,
    this.tonerCyan,
    this.tonerMagenta,
    this.tonerYellow,
    this.ignoredIds = const [],
  });

  final int? pagesTotal;
  final int? pagesColor;
  final int? pagesBlackAndWhite;
  final int? beltRemainingPages;
  final int? fuserRemainingPages;
  final int? tonerBlack;
  final int? tonerCyan;
  final int? tonerMagenta;
  final int? tonerYellow;
  final List<int> ignoredIds;
}

/// Tag, 0x01, 0x04, four big-endian bytes. 0xFFFFFF is padding.
BrotherUsbRecords decodeBrotherUsbRecords(List<int> bytes) {
  int? pagesTotal;
  int? pagesColor;
  int? pagesBlackAndWhite;
  int? belt;
  int? fuser;
  int? tonerBlack;
  int? tonerCyan;
  int? tonerMagenta;
  int? tonerYellow;
  final ignored = <int>[];
  var i = 0;
  while (i < bytes.length) {
    if (i + 4 <= bytes.length &&
        bytes[i] == 0xFF &&
        bytes[i + 1] == 0xFF &&
        bytes[i + 2] == 0xFF &&
        bytes[i + 3] == 0xFF) {
      break;
    }
    if (i + 3 <= bytes.length &&
        bytes[i] == 0xFF &&
        bytes[i + 1] == 0xFF &&
        bytes[i + 2] == 0xFF) {
      i += 3;
      continue;
    }
    if (bytes[i] == 0xFF && i + 1 == bytes.length) {
      break;
    }
    if (i + 3 > bytes.length || bytes[i + 1] != 0x01 || bytes[i + 2] != 0x04) {
      break;
    }
    final id = bytes[i];
    i += 3;
    final valueBytes = <int>[];
    while (valueBytes.length < 4 && i < bytes.length) {
      if (i + 3 <= bytes.length &&
          bytes[i] == 0xFF &&
          bytes[i + 1] == 0xFF &&
          bytes[i + 2] == 0xFF) {
        i += 3;
        continue;
      }
      valueBytes.add(bytes[i]);
      i += 1;
    }
    if (valueBytes.length != 4) {
      break;
    }
    final value = (valueBytes[0] << 24) |
        (valueBytes[1] << 16) |
        (valueBytes[2] << 8) |
        valueBytes[3];
    if (value < 0) {
      ignored.add(id);
      continue;
    }
    switch (id) {
      case 0:
        pagesTotal = value;
        break;
      case 1:
        pagesBlackAndWhite = value;
        break;
      case 2:
        pagesColor = value;
        break;
      case 136:
        belt = value;
        break;
      case 115:
        fuser = value;
        break;
      case 129:
        if (value <= 100) tonerBlack = value;
        break;
      case 130:
        if (value <= 100) tonerCyan = value;
        break;
      case 131:
        if (value <= 100) tonerMagenta = value;
        break;
      case 132:
        if (value <= 100) tonerYellow = value;
        break;
      default:
        ignored.add(id);
    }
  }
  return BrotherUsbRecords(
    pagesTotal: pagesTotal,
    pagesColor: pagesColor,
    pagesBlackAndWhite: pagesBlackAndWhite,
    beltRemainingPages: belt,
    fuserRemainingPages: fuser,
    tonerBlack: tonerBlack,
    tonerCyan: tonerCyan,
    tonerMagenta: tonerMagenta,
    tonerYellow: tonerYellow,
    ignoredIds: ignored,
  );
}

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
    final records = _recordsFromHex(json['pageCountHex'])
        .merge(_recordsFromHex(json['nextCareHex']));
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
      pagesTotal: (json['pagesTotal'] as num?)?.toInt() ?? records.pagesTotal,
      pagesColor: (json['pagesColor'] as num?)?.toInt() ?? records.pagesColor,
      pagesBlackAndWhite: (json['pagesBlackAndWhite'] as num?)?.toInt() ??
          records.pagesBlackAndWhite,
      beltRemainingPages: (json['beltRemainingPages'] as num?)?.toInt() ??
          records.beltRemainingPages,
      fuserRemainingPages: (json['fuserRemainingPages'] as num?)?.toInt() ??
          records.fuserRemainingPages,
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

extension on BrotherUsbRecords {
  BrotherUsbRecords merge(BrotherUsbRecords other) {
    return BrotherUsbRecords(
      pagesTotal: pagesTotal ?? other.pagesTotal,
      pagesColor: pagesColor ?? other.pagesColor,
      pagesBlackAndWhite: pagesBlackAndWhite ?? other.pagesBlackAndWhite,
      beltRemainingPages: beltRemainingPages ?? other.beltRemainingPages,
      fuserRemainingPages: fuserRemainingPages ?? other.fuserRemainingPages,
      tonerBlack: tonerBlack ?? other.tonerBlack,
      tonerCyan: tonerCyan ?? other.tonerCyan,
      tonerMagenta: tonerMagenta ?? other.tonerMagenta,
      tonerYellow: tonerYellow ?? other.tonerYellow,
      ignoredIds: [...ignoredIds, ...other.ignoredIds],
    );
  }
}

BrotherUsbRecords _recordsFromHex(Object? raw) {
  if (raw is! String || raw.isEmpty) {
    return const BrotherUsbRecords();
  }
  final hex = raw.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (hex.length < 2 || hex.length.isOdd) {
    return const BrotherUsbRecords();
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return decodeBrotherUsbRecords(bytes);
}

/// Lab-confirmed Brother QueryStatus codes. Anything else is unmapped.
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
