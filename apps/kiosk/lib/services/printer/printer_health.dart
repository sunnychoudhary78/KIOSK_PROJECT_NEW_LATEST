class PrinterTrayHealth {
  const PrinterTrayHealth({
    required this.name,
    this.levelPercent,
    this.status,
  });

  final String name;
  final int? levelPercent;
  final String? status;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (levelPercent != null) 'levelPercent': levelPercent,
        if (status != null) 'status': status,
      };

  factory PrinterTrayHealth.fromJson(Map<String, dynamic> json) {
    return PrinterTrayHealth(
      name: json['name'] as String? ?? 'Tray',
      levelPercent: (json['levelPercent'] as num?)?.toInt(),
      status: json['status'] as String?,
    );
  }
}

class PrinterSupplyHealth {
  const PrinterSupplyHealth({
    required this.name,
    required this.color,
    this.levelPercent,
    this.status,
  });

  final String name;
  final String color;
  final int? levelPercent;
  final String? status;

  Map<String, dynamic> toJson() => {
        'name': name,
        'color': color,
        if (levelPercent != null) 'levelPercent': levelPercent,
        if (status != null) 'status': status,
      };

  factory PrinterSupplyHealth.fromJson(Map<String, dynamic> json) {
    return PrinterSupplyHealth(
      name: json['name'] as String? ?? 'Toner',
      color: json['color'] as String? ?? 'unknown',
      levelPercent: (json['levelPercent'] as num?)?.toInt(),
      status: json['status'] as String?,
    );
  }
}

/// Matches API `PrinterHealth` / OpenAPI schema.
class PrinterHealth {
  const PrinterHealth({
    required this.state,
    required this.online,
    this.printerName,
    this.model,
    this.trays = const [],
    this.supplies = const [],
    this.pageCounter,
    this.snmpOk,
    this.lastErrorCode,
    this.lastErrorAt,
  });

  final String state;
  final bool online;
  final String? printerName;
  final String? model;
  final List<PrinterTrayHealth> trays;
  final List<PrinterSupplyHealth> supplies;
  final int? pageCounter;
  final bool? snmpOk;
  final String? lastErrorCode;
  final String? lastErrorAt;

  bool get isFatal =>
      state == 'jam' ||
      state == 'paper_out' ||
      state == 'offline' ||
      state == 'error';

  String get userMessage {
    switch (state) {
      case 'jam':
        return 'Paper jam — clear the printer and try again.';
      case 'paper_out':
        return 'Printer is out of paper — load A4 and try again.';
      case 'toner_low':
        return 'Toner is low — printing may still work.';
      case 'offline':
        return 'Printer is offline — check power and Wi‑Fi.';
      case 'error':
        return 'Printer error — check the device panel.';
      case 'printing':
        return 'Printer is busy…';
      default:
        return 'Printer ready';
    }
  }

  Map<String, dynamic> toJson() => {
        'state': state,
        'online': online,
        if (printerName != null) 'printerName': printerName,
        if (model != null) 'model': model,
        if (trays.isNotEmpty) 'trays': trays.map((t) => t.toJson()).toList(),
        if (supplies.isNotEmpty)
          'supplies': supplies.map((s) => s.toJson()).toList(),
        if (pageCounter != null) 'pageCounter': pageCounter,
        if (snmpOk != null) 'snmpOk': snmpOk,
        if (lastErrorCode != null) 'lastErrorCode': lastErrorCode,
        if (lastErrorAt != null) 'lastErrorAt': lastErrorAt,
      };

  factory PrinterHealth.fromJson(Map<dynamic, dynamic> json) {
    final traysRaw = json['trays'];
    final suppliesRaw = json['supplies'];
    return PrinterHealth(
      state: json['state'] as String? ?? 'unknown',
      online: json['online'] as bool? ?? false,
      printerName: json['printerName'] as String?,
      model: json['model'] as String?,
      trays: traysRaw is List
          ? traysRaw
              .whereType<Map>()
              .map((e) => PrinterTrayHealth.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      supplies: suppliesRaw is List
          ? suppliesRaw
              .whereType<Map>()
              .map(
                (e) => PrinterSupplyHealth.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
          : const [],
      pageCounter: (json['pageCounter'] as num?)?.toInt(),
      snmpOk: json['snmpOk'] as bool?,
      lastErrorCode: json['lastErrorCode'] as String?,
      lastErrorAt: json['lastErrorAt'] as String?,
    );
  }

  static const unknown = PrinterHealth(state: 'unknown', online: false);
}
