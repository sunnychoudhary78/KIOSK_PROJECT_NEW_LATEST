import 'package:skp_admin/core/format.dart';
import 'package:skp_admin/features/printer/data/printer_health.dart';

enum PrinterRowTone { muted, ok, amber, alert }

class PrinterRowSummary {
  const PrinterRowSummary({required this.label, required this.tone});

  final String label;
  final PrinterRowTone tone;
}

enum PrinterStatusKind {
  ready,
  printing,
  paperOut,
  jam,
  tonerLow,
  offline,
  error,
  unavailable,
}

class PrinterStatusDisplay {
  const PrinterStatusDisplay({
    required this.label,
    required this.kind,
    required this.fault,
  });

  final String label;
  final PrinterStatusKind kind;
  final bool fault;
}

class MaintenanceMetricLines {
  const MaintenanceMetricLines({
    required this.black,
    required this.cyan,
    required this.magenta,
    required this.yellow,
    required this.total,
    required this.color,
    required this.blackAndWhite,
    required this.belt,
    required this.fuser,
  });

  final String black;
  final String cyan;
  final String magenta;
  final String yellow;
  final String total;
  final String color;
  final String blackAndWhite;
  final String belt;
  final String fuser;
}

sealed class MaintenanceDisplay {
  const MaintenanceDisplay();
}

class MaintenanceUnavailable extends MaintenanceDisplay {
  const MaintenanceUnavailable();
}

class MaintenanceShown extends MaintenanceDisplay {
  const MaintenanceShown({
    required this.stale,
    required this.lines,
    this.title,
  });

  final bool stale;
  final String? title;
  final MaintenanceMetricLines lines;
}

class RecordedError {
  const RecordedError({required this.index, required this.description});

  final int index;
  final String description;
}

sealed class ErrorHistoryDisplay {
  const ErrorHistoryDisplay();
}

class ErrorHistoryUnavailable extends ErrorHistoryDisplay {
  const ErrorHistoryUnavailable();
}

class ErrorHistoryEmpty extends ErrorHistoryDisplay {
  const ErrorHistoryEmpty();
}

class ErrorHistoryShown extends ErrorHistoryDisplay {
  const ErrorHistoryShown({
    required this.stale,
    required this.entries,
    this.title,
  });

  final bool stale;
  final String? title;
  final List<RecordedError> entries;
}

const _statusLabels = <String, PrinterStatusKind>{
  'ready': PrinterStatusKind.ready,
  'printing': PrinterStatusKind.printing,
  'paper_out': PrinterStatusKind.paperOut,
  'jam': PrinterStatusKind.jam,
  'toner_low': PrinterStatusKind.tonerLow,
  'offline': PrinterStatusKind.offline,
  'error': PrinterStatusKind.error,
};

const _faults = {
  PrinterStatusKind.paperOut,
  PrinterStatusKind.jam,
  PrinterStatusKind.tonerLow,
  PrinterStatusKind.offline,
  PrinterStatusKind.error,
};

String formatPercent(num? value) {
  if (value == null || value % 1 != 0) return printerMissing;
  final whole = value.toInt();
  if (whole < 0 || whole > 100) return printerMissing;
  return '$whole%';
}

String formatCount(num? value) {
  if (!isWholeCount(value)) return printerMissing;
  final digits = value!.toInt().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String? lastPollTitle(String? lastSuccessAt) {
  final parsed = DateTime.tryParse(lastSuccessAt ?? '');
  if (parsed == null) return null;
  return 'Last successful printer poll ${formatTimestamp(parsed)}';
}

MaintenanceDisplay resolvePrinterMaintenance(PrinterHealth? health) {
  final maintenance = health?.maintenance;
  if (maintenance == null || maintenance.available != true) {
    return const MaintenanceUnavailable();
  }
  final lines = MaintenanceMetricLines(
    black: formatPercent(maintenance.toner?.blackPercent),
    cyan: formatPercent(maintenance.toner?.cyanPercent),
    magenta: formatPercent(maintenance.toner?.magentaPercent),
    yellow: formatPercent(maintenance.toner?.yellowPercent),
    total: formatCount(maintenance.pages?.total),
    color: formatCount(maintenance.pages?.color),
    blackAndWhite: formatCount(maintenance.pages?.blackAndWhite),
    belt: formatCount(maintenance.parts?.beltRemainingPages),
    fuser: formatCount(maintenance.parts?.fuserRemainingPages),
  );
  if (health?.snmpOk == false) {
    return MaintenanceShown(
      stale: true,
      title: lastPollTitle(health?.lastSuccessAt),
      lines: lines,
    );
  }
  return MaintenanceShown(stale: false, lines: lines);
}

ErrorHistoryDisplay resolvePrinterErrorHistory(PrinterHealth? health) {
  final history = health?.errorHistory;
  if (history == null || history.available != true) {
    return const ErrorHistoryUnavailable();
  }
  final entries = _errorEntries(history);
  if (health?.snmpOk == false) {
    return ErrorHistoryShown(
      stale: true,
      title: lastPollTitle(health?.lastSuccessAt),
      entries: entries,
    );
  }
  if (entries.isEmpty) return const ErrorHistoryEmpty();
  return ErrorHistoryShown(stale: false, entries: entries);
}

PrinterStatusDisplay resolvePrinterStatus(PrinterHealth? health) {
  final kind = _statusLabels[health?.state];
  if (kind == null) {
    return const PrinterStatusDisplay(
      label: 'Unavailable',
      kind: PrinterStatusKind.unavailable,
      fault: false,
    );
  }
  return PrinterStatusDisplay(
    label: switch (kind) {
      PrinterStatusKind.ready => 'Ready',
      PrinterStatusKind.printing => 'Printing',
      PrinterStatusKind.paperOut => 'Out of paper',
      PrinterStatusKind.jam => 'Paper jam',
      PrinterStatusKind.tonerLow => 'Toner low',
      PrinterStatusKind.offline => 'Offline',
      PrinterStatusKind.error => 'Error',
      PrinterStatusKind.unavailable => 'Unavailable',
    },
    kind: kind,
    fault: _faults.contains(kind),
  );
}

PrinterRowSummary resolvePrinterRowSummary(PrinterHealth? health) {
  final maintenance = resolvePrinterMaintenance(health);
  final errors = resolvePrinterErrorHistory(health);
  final status = resolvePrinterStatus(health);
  final stale = maintenance is MaintenanceShown && maintenance.stale ||
      errors is ErrorHistoryShown && errors.stale;
  final recorded = errors is ErrorHistoryShown ? errors.entries.length : 0;

  if (status.fault) {
    return PrinterRowSummary(
      label: status.label,
      tone: health?.snmpOk == false ? PrinterRowTone.amber : PrinterRowTone.alert,
    );
  }
  if (recorded > 0) {
    return PrinterRowSummary(
      label: recorded == 1 ? '1 error' : '$recorded errors',
      tone: stale ? PrinterRowTone.amber : PrinterRowTone.alert,
    );
  }
  if (stale) {
    return const PrinterRowSummary(label: 'Stale', tone: PrinterRowTone.amber);
  }
  if (maintenance is MaintenanceShown) {
    if (status.kind == PrinterStatusKind.ready || status.kind == PrinterStatusKind.printing) {
      return PrinterRowSummary(label: status.label, tone: PrinterRowTone.ok);
    }
    return const PrinterRowSummary(label: 'OK', tone: PrinterRowTone.ok);
  }
  return const PrinterRowSummary(label: 'Unavailable', tone: PrinterRowTone.muted);
}

List<RecordedError> _errorEntries(PrinterErrorHistory history) {
  final entries = <RecordedError>[];
  for (final entry in history.entries) {
    final index = entry.index;
    final description = entry.description;
    if (index == null ||
        index % 1 != 0 ||
        index < 1 ||
        index > 10 ||
        description == null ||
        description.trim().isEmpty) {
      continue;
    }
    entries.add(RecordedError(index: index.toInt(), description: description.trim()));
    if (entries.length == 10) break;
  }
  return entries;
}

/// True when a printer-refresh poll should stop, matching the web panel:
/// the pending request is clear and [printerHealthAt] is at or after [requestedAt].
bool printerRefreshSettled({
  required String? printerHealthAt,
  required String? printerRefreshRequestedAt,
  required String requestedAt,
}) {
  if (printerRefreshRequestedAt != null && printerRefreshRequestedAt.isNotEmpty) {
    return false;
  }
  final posted = DateTime.tryParse(printerHealthAt ?? '');
  final requested = DateTime.tryParse(requestedAt);
  if (posted == null || requested == null) return false;
  return !posted.isBefore(requested);
}

/// Returns an error message, or null when [input] is a whole number from 1 to 2000.
String? validateTrayPages(String input) {
  final pages = int.tryParse(input.trim());
  if (pages == null || pages < 1 || pages > 2000) {
    return 'Enter a whole number of pages from 1 to 2000';
  }
  return null;
}
