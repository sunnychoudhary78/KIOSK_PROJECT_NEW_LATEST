import 'package:skp_kiosk/services/printer/printer_health.dart';
import 'package:skp_kiosk/services/printer/usb_snapshot.dart';

/// Pure HTML parsers mirroring `BridgeHtml.cs` for DCP-T830DW fixtures/tests.
class BrotherBridgeMonitor {
  const BrotherBridgeMonitor({
    this.statusCode,
    this.statusMessage,
    this.statusType,
  });

  final int? statusCode;
  final String? statusMessage;
  final String? statusType;
}

class BrotherBridgeMaintenance {
  const BrotherBridgeMaintenance({
    this.pagesTotal,
    this.pagesColor,
    this.pagesBlackAndWhite,
    this.pagesDuplexTotal,
    this.pagesDuplexColor,
    this.pagesDuplexBlackAndWhite,
    this.tonerBlack,
    this.tonerCyan,
    this.tonerMagenta,
    this.tonerYellow,
    this.refillBlack,
    this.refillCyan,
    this.refillMagenta,
    this.refillYellow,
    this.model,
    this.serialNumber,
    this.firmwareMain,
    this.errorHistory = const [],
  });

  final int? pagesTotal;
  final int? pagesColor;
  final int? pagesBlackAndWhite;
  final int? pagesDuplexTotal;
  final int? pagesDuplexColor;
  final int? pagesDuplexBlackAndWhite;
  final int? tonerBlack;
  final int? tonerCyan;
  final int? tonerMagenta;
  final int? tonerYellow;
  final int? refillBlack;
  final int? refillCyan;
  final int? refillMagenta;
  final int? refillYellow;
  final String? model;
  final String? serialNumber;
  final String? firmwareMain;
  final List<PrinterErrorHistoryEntry> errorHistory;
}

final _monitorFragment = RegExp(
  r'monitor_start[^>]*>\s*<span\s+class="moni\s+([^"]+)">([^<]*)</span>',
  caseSensitive: false,
);

final _dtDd = RegExp(
  r'<dt[^>]*>(.*?)</dt>\s*<dd[^>]*>(.*?)</dd>',
  caseSensitive: false,
  dotAll: true,
);

final _tableRow = RegExp(
  r'<tr[^>]*>(.*?)</tr>',
  caseSensitive: false,
  dotAll: true,
);

final _tableCell = RegExp(
  r'<t[hd][^>]*>(.*?)</t[hd]>',
  caseSensitive: false,
  dotAll: true,
);

final _tag = RegExp(r'<[^>]+>');

BrotherBridgeMonitor parseBrotherMonitorHtml(String html) {
  final match = _monitorFragment.firstMatch(html);
  if (match == null) return const BrotherBridgeMonitor();
  final css = match.group(1)?.trim() ?? '';
  final text = _decode(match.group(2) ?? '').trim();
  return BrotherBridgeMonitor(
    statusCode: statusCodeFromBrotherMessage(text),
    statusMessage: text.isEmpty ? null : text,
    statusType: _statusTypeFromClass(css),
  );
}

BrotherBridgeMaintenance parseBrotherMaintenanceHtml(
  String html, {
  bool includeErrors = true,
}) {
  int? pagesTotal;
  int? pagesColor;
  int? pagesBlackAndWhite;
  int? pagesDuplexTotal;
  int? pagesDuplexColor;
  int? pagesDuplexBlackAndWhite;
  int? tonerBlack;
  int? tonerCyan;
  int? tonerMagenta;
  int? tonerYellow;
  int? refillBlack;
  int? refillCyan;
  int? refillMagenta;
  int? refillYellow;
  String? model;
  String? serialNumber;
  String? firmwareMain;
  var awaitingPageColour = false;
  var acceptDuplex = true;

  for (final match in _dtDd.allMatches(html)) {
    final label = _normalizeLabel(_decode(_stripTags(match.group(1) ?? '')));
    final value = _decode(_stripTags(match.group(2) ?? '')).trim();
    if (label.isEmpty) continue;
    final lower = label.toLowerCase();

    if (lower == 'copy') {
      acceptDuplex = false;
      continue;
    }
    if (lower == 'page counter') {
      pagesTotal = _parseInt(value);
      awaitingPageColour = true;
      continue;
    }
    if (awaitingPageColour && lower == 'colour') {
      pagesColor = _parseInt(value);
      continue;
    }
    if (awaitingPageColour &&
        (lower == 'b&w' ||
            lower == 'b&amp;w' ||
            lower == 'black and white')) {
      pagesBlackAndWhite = _parseInt(value);
      awaitingPageColour = false;
      continue;
    }
    if (acceptDuplex && lower == '2-sided print') {
      pagesDuplexTotal ??= _parseInt(value);
      continue;
    }
    if (acceptDuplex && lower == 'colour 2-sided') {
      pagesDuplexColor ??= _parseInt(value);
      continue;
    }
    if (acceptDuplex &&
        (lower == 'b&w 2-sided' || lower == 'b&amp;w 2-sided')) {
      pagesDuplexBlackAndWhite ??= _parseInt(value);
      continue;
    }
    if (lower.startsWith('ink') && value.contains('%')) {
      final percent = _parsePercent(value);
      if (percent == null) continue;
      if (lower.contains('black') || lower.contains('(bk)')) {
        tonerBlack = percent;
      } else if (lower.contains('cyan')) {
        tonerCyan = percent;
      } else if (lower.contains('magenta')) {
        tonerMagenta = percent;
      } else if (lower.contains('yellow')) {
        tonerYellow = percent;
      }
      awaitingPageColour = false;
      continue;
    }
    if (lower.startsWith('ink') && !value.contains('%')) {
      final count = _parseInt(value);
      if (count == null) continue;
      if (lower.contains('black') || lower.contains('(bk)')) {
        refillBlack = count;
      } else if (lower.contains('cyan')) {
        refillCyan = count;
      } else if (lower.contains('magenta')) {
        refillMagenta = count;
      } else if (lower.contains('yellow')) {
        refillYellow = count;
      }
      continue;
    }
    if (lower == 'model name') {
      model = value.isEmpty ? null : value;
      continue;
    }
    if (lower == 'serial no.' || lower == 'serial number') {
      serialNumber = value.isEmpty ? null : value;
      continue;
    }
    if (lower == 'main firmware version') {
      firmwareMain = value.isEmpty ? null : value;
    }
  }

  final errors = <PrinterErrorHistoryEntry>[];
  if (includeErrors) {
    for (final row in _tableRow.allMatches(html)) {
      final cells = _tableCell
          .allMatches(row.group(1) ?? '')
          .map((cell) => _decode(_stripTags(cell.group(1) ?? '')).trim())
          .toList();
      if (cells.length < 2) continue;
      final index = int.tryParse(cells[0]);
      if (index == null || index < 1 || index > 10) continue;
      var description = cells[1];
      if (description.isEmpty) continue;
      if (description.length > 160) {
        description = description.substring(0, 160);
      }
      errors.add(PrinterErrorHistoryEntry(index: index, description: description));
    }
  }

  return BrotherBridgeMaintenance(
    pagesTotal: pagesTotal,
    pagesColor: pagesColor,
    pagesBlackAndWhite: pagesBlackAndWhite,
    pagesDuplexTotal: pagesDuplexTotal,
    pagesDuplexColor: pagesDuplexColor,
    pagesDuplexBlackAndWhite: pagesDuplexBlackAndWhite,
    tonerBlack: tonerBlack,
    tonerCyan: tonerCyan,
    tonerMagenta: tonerMagenta,
    tonerYellow: tonerYellow,
    refillBlack: refillBlack,
    refillCyan: refillCyan,
    refillMagenta: refillMagenta,
    refillYellow: refillYellow,
    model: model,
    serialNumber: serialNumber,
    firmwareMain: firmwareMain,
    errorHistory: errors,
  );
}

UsbSnapshot snapshotFromBrotherBridgeHtml({
  required String monitorHtml,
  required String maintenanceHtml,
  bool full = false,
}) {
  final monitor = parseBrotherMonitorHtml(monitorHtml);
  final maintenance = parseBrotherMaintenanceHtml(
    maintenanceHtml,
    includeErrors: full,
  );
  return UsbSnapshot(
    ok: true,
    connected: true,
    statusCode: monitor.statusCode,
    statusMessage: monitor.statusMessage,
    statusType: monitor.statusType,
    tonerBlack: maintenance.tonerBlack,
    tonerCyan: maintenance.tonerCyan,
    tonerMagenta: maintenance.tonerMagenta,
    tonerYellow: maintenance.tonerYellow,
    pagesTotal: maintenance.pagesTotal,
    pagesColor: maintenance.pagesColor,
    pagesBlackAndWhite: maintenance.pagesBlackAndWhite,
    pagesDuplexTotal: maintenance.pagesDuplexTotal,
    pagesDuplexColor: maintenance.pagesDuplexColor,
    pagesDuplexBlackAndWhite: maintenance.pagesDuplexBlackAndWhite,
    refillBlack: maintenance.refillBlack,
    refillCyan: maintenance.refillCyan,
    refillMagenta: maintenance.refillMagenta,
    refillYellow: maintenance.refillYellow,
    firmwareMain: maintenance.firmwareMain,
    model: maintenance.model,
    serialNumber: maintenance.serialNumber,
    errorHistory: full ? maintenance.errorHistory : null,
  );
}

int? statusCodeFromBrotherMessage(String? message) {
  if (message == null || message.trim().isEmpty) return null;
  final text = message.trim().toLowerCase();
  if (text.contains('sleep')) return usbStatusSleep;
  if (text.contains('printing')) return usbStatusPrinting;
  if (text.contains('please wait') || text == 'wait') return usbStatusWait;
  if (text.contains('ready') || text.contains('idle')) return usbStatusReady;
  if (_isPaperOut(text)) return usbStatusPaperOut;
  return null;
}

bool _isPaperOut(String text) {
  if (text.contains('out of paper')) return true;
  if (text.contains('paper empty')) return true;
  if (text.contains('no paper')) return true;
  if (text.contains('load paper')) return true;
  if (text.contains('paper tray') &&
      (text.contains('empty') ||
          text.contains('not detected') ||
          text.contains('out'))) {
    return true;
  }
  return false;
}

String? _statusTypeFromClass(String css) {
  if (css.isEmpty) return null;
  final lower = css.toLowerCase();
  if (lower.contains('monierror')) return 'Error';
  if (lower.contains('moniwarning')) return 'Warning';
  if (lower.contains('moniok')) return 'Ready';
  if (lower.contains('monietc')) return 'Etc';
  return css;
}

String _stripTags(String value) => value.replaceAll(_tag, '');

String _decode(String value) {
  return value
      .replaceAll('&#32;', ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('\u00A0', ' ');
}

String _normalizeLabel(String label) =>
    label.trim().replaceAll(RegExp(r'\s+'), ' ');

int? _parseInt(String value) {
  final match = RegExp(r'-?\d+').firstMatch(value);
  if (match == null) return null;
  final number = int.tryParse(match.group(0)!);
  if (number == null || number < 0) return null;
  return number;
}

int? _parsePercent(String value) {
  final number = _parseInt(value);
  if (number == null || number > 100) return null;
  return number;
}
