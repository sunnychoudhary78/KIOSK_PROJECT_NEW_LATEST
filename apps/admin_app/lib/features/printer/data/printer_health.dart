const printerMissing = '—';

class TonerLevels {
  const TonerLevels({
    this.blackPercent,
    this.cyanPercent,
    this.magentaPercent,
    this.yellowPercent,
  });

  final num? blackPercent;
  final num? cyanPercent;
  final num? magentaPercent;
  final num? yellowPercent;

  factory TonerLevels.fromJson(Map<String, dynamic> json) {
    return TonerLevels(
      blackPercent: _num(json['blackPercent']),
      cyanPercent: _num(json['cyanPercent']),
      magentaPercent: _num(json['magentaPercent']),
      yellowPercent: _num(json['yellowPercent']),
    );
  }
}

class PageCounts {
  const PageCounts({
    this.total,
    this.color,
    this.blackAndWhite,
    this.duplexTotal,
    this.duplexColor,
    this.duplexBlackAndWhite,
  });

  final num? total;
  final num? color;
  final num? blackAndWhite;
  final num? duplexTotal;
  final num? duplexColor;
  final num? duplexBlackAndWhite;

  factory PageCounts.fromJson(Map<String, dynamic> json) {
    return PageCounts(
      total: _num(json['total']),
      color: _num(json['color']),
      blackAndWhite: _num(json['blackAndWhite']),
      duplexTotal: _num(json['duplexTotal']),
      duplexColor: _num(json['duplexColor']),
      duplexBlackAndWhite: _num(json['duplexBlackAndWhite']),
    );
  }
}

class RefillCounts {
  const RefillCounts({this.black, this.cyan, this.magenta, this.yellow});

  final num? black;
  final num? cyan;
  final num? magenta;
  final num? yellow;

  factory RefillCounts.fromJson(Map<String, dynamic> json) {
    return RefillCounts(
      black: _num(json['black']),
      cyan: _num(json['cyan']),
      magenta: _num(json['magenta']),
      yellow: _num(json['yellow']),
    );
  }
}

class PartLife {
  const PartLife({this.beltRemainingPages, this.fuserRemainingPages});

  final num? beltRemainingPages;
  final num? fuserRemainingPages;

  factory PartLife.fromJson(Map<String, dynamic> json) {
    return PartLife(
      beltRemainingPages: _num(json['beltRemainingPages']),
      fuserRemainingPages: _num(json['fuserRemainingPages']),
    );
  }
}

class PrinterMaintenance {
  const PrinterMaintenance({
    this.available,
    this.toner,
    this.pages,
    this.refill,
    this.parts,
  });

  final bool? available;
  final TonerLevels? toner;
  final PageCounts? pages;
  final RefillCounts? refill;
  final PartLife? parts;

  factory PrinterMaintenance.fromJson(Map<String, dynamic> json) {
    return PrinterMaintenance(
      available: json['available'] is bool ? json['available'] as bool : null,
      toner: json['toner'] is Map
          ? TonerLevels.fromJson(Map<String, dynamic>.from(json['toner'] as Map))
          : null,
      pages: json['pages'] is Map
          ? PageCounts.fromJson(Map<String, dynamic>.from(json['pages'] as Map))
          : null,
      refill: json['refill'] is Map
          ? RefillCounts.fromJson(Map<String, dynamic>.from(json['refill'] as Map))
          : null,
      parts: json['parts'] is Map
          ? PartLife.fromJson(Map<String, dynamic>.from(json['parts'] as Map))
          : null,
    );
  }
}

class PrinterErrorEntry {
  const PrinterErrorEntry({this.index, this.description});

  final num? index;
  final String? description;

  factory PrinterErrorEntry.fromJson(Map<String, dynamic> json) {
    return PrinterErrorEntry(
      index: _num(json['index']),
      description: json['description'] as String?,
    );
  }
}

class PrinterErrorHistory {
  const PrinterErrorHistory({this.available, this.entries = const []});

  final bool? available;
  final List<PrinterErrorEntry> entries;

  factory PrinterErrorHistory.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'];
    final entries = raw is List
        ? raw
            .whereType<Map>()
            .map((entry) => PrinterErrorEntry.fromJson(Map<String, dynamic>.from(entry)))
            .toList()
        : const <PrinterErrorEntry>[];
    return PrinterErrorHistory(
      available: json['available'] is bool ? json['available'] as bool : null,
      entries: entries,
    );
  }
}

class PrinterHealth {
  const PrinterHealth({
    this.state,
    this.noPaper,
    this.snmpOk,
    this.lastSuccessAt,
    this.maintenance,
    this.errorHistory,
  });

  final String? state;
  final bool? noPaper;
  final bool? snmpOk;
  final String? lastSuccessAt;
  final PrinterMaintenance? maintenance;
  final PrinterErrorHistory? errorHistory;

  bool get reportsPaperOut => state == 'paper_out' || noPaper == true;

  factory PrinterHealth.fromJson(Map<String, dynamic> json) {
    return PrinterHealth(
      state: json['state'] as String?,
      noPaper: json['noPaper'] is bool ? json['noPaper'] as bool : null,
      snmpOk: json['snmpOk'] is bool ? json['snmpOk'] as bool : null,
      lastSuccessAt: json['lastSuccessAt'] as String?,
      maintenance: json['maintenance'] is Map
          ? PrinterMaintenance.fromJson(Map<String, dynamic>.from(json['maintenance'] as Map))
          : null,
      errorHistory: json['errorHistory'] is Map
          ? PrinterErrorHistory.fromJson(Map<String, dynamic>.from(json['errorHistory'] as Map))
          : null,
    );
  }
}

int? usbPagesTotal(PrinterHealth? health) {
  final total = health?.maintenance?.pages?.total;
  if (!isWholeCount(total)) return null;
  return total!.toInt();
}

bool isWholeCount(num? value) => value != null && value % 1 == 0 && value >= 0;

num? _num(dynamic value) => value is num ? value : null;
