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

/// Matches API heartbeat `printer` blob (never includes SNMP community).
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
    this.snmpReachable,
    this.snmpConfigured,
    this.consecutiveFailures,
    this.lastSuccessAtMs,
    this.lastAttemptAtMs,
    this.lastPollError,
    this.hrPrinterStatus,
    this.hrPrinterStatusLabel,
    this.errorFlagsHex,
    this.noPaper = false,
    this.jammed = false,
    this.offlineBit = false,
    this.lowPaper = false,
    this.lowToner = false,
    this.noToner = false,
    this.doorOpen = false,
    this.spoolerJobsQueued,
    this.spoolerJobsPrinting,
    this.spoolerLatestJobId,
    this.spoolerLatestJobStatus,
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
  final bool? snmpReachable;
  final bool? snmpConfigured;
  final int? consecutiveFailures;
  final int? lastSuccessAtMs;
  final int? lastAttemptAtMs;
  final String? lastPollError;
  final int? hrPrinterStatus;
  final String? hrPrinterStatusLabel;
  final String? errorFlagsHex;
  final bool noPaper;
  final bool jammed;
  final bool offlineBit;
  final bool lowPaper;
  final bool lowToner;
  final bool noToner;
  final bool doorOpen;
  final int? spoolerJobsQueued;
  final int? spoolerJobsPrinting;
  final int? spoolerLatestJobId;
  final String? spoolerLatestJobStatus;
  final String? lastErrorCode;
  final String? lastErrorAt;

  /// Fatal for blocking a new print. Offline bit alone is NOT fatal.
  bool get isFatal {
    if (state == 'jam' || jammed) return true;
    if (state == 'paper_out' || noPaper) return true;
    if (state == 'error') return true;
    if (state == 'offline' && online == false) return true;
    if (snmpConfigured == true && snmpReachable == false) return true;
    return false;
  }

  bool get isBusy =>
      state == 'printing' ||
      hrPrinterStatus == 4 ||
      hrPrinterStatus == 5 ||
      (spoolerJobsPrinting ?? 0) > 0;

  String get userMessage {
    if (jammed || state == 'jam') {
      return 'Paper jam — clear the printer and try again.';
    }
    if (noPaper || state == 'paper_out') {
      return 'Printer is out of paper — load A4 and try again.';
    }
    if (state == 'toner_low' || lowToner || noToner) {
      return 'Toner is low — printing may still work.';
    }
    if (snmpConfigured == true && snmpReachable == false) {
      return 'Printer SNMP unreachable — check network and try again.';
    }
    if (state == 'offline') {
      return 'Printer is offline — check power and Wi‑Fi.';
    }
    if (state == 'error') {
      return 'Printer error — check the device panel.';
    }
    if (isBusy) {
      return 'Printer is busy…';
    }
    return 'Printer ready';
  }

  /// Heartbeat / API payload — never includes community or host secrets.
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
        if (snmpReachable != null) 'snmpReachable': snmpReachable,
        if (consecutiveFailures != null)
          'consecutiveFailures': consecutiveFailures,
        if (lastSuccessAtMs != null)
          'lastSuccessAt': DateTime.fromMillisecondsSinceEpoch(lastSuccessAtMs!)
              .toUtc()
              .toIso8601String(),
        if (lastPollError != null) 'lastPollError': lastPollError,
        if (hrPrinterStatus != null) 'hrPrinterStatus': hrPrinterStatus,
        if (hrPrinterStatusLabel != null)
          'hrPrinterStatusLabel': hrPrinterStatusLabel,
        if (errorFlagsHex != null) 'errorFlagsHex': errorFlagsHex,
        'noPaper': noPaper,
        'jammed': jammed,
        'offlineBit': offlineBit,
        if (spoolerJobsQueued != null) 'spoolerJobsQueued': spoolerJobsQueued,
        if (spoolerJobsPrinting != null)
          'spoolerJobsPrinting': spoolerJobsPrinting,
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
      snmpReachable: json['snmpReachable'] as bool?,
      snmpConfigured: json['snmpConfigured'] as bool?,
      consecutiveFailures: (json['consecutiveFailures'] as num?)?.toInt(),
      lastSuccessAtMs: (json['lastSuccessAtMs'] as num?)?.toInt(),
      lastAttemptAtMs: (json['lastAttemptAtMs'] as num?)?.toInt(),
      lastPollError: json['lastPollError'] as String?,
      hrPrinterStatus: (json['hrPrinterStatus'] as num?)?.toInt(),
      hrPrinterStatusLabel: json['hrPrinterStatusLabel'] as String?,
      errorFlagsHex: json['errorFlagsHex'] as String?,
      noPaper: json['noPaper'] as bool? ?? false,
      jammed: json['jammed'] as bool? ?? false,
      offlineBit: json['offlineBit'] as bool? ?? false,
      lowPaper: json['lowPaper'] as bool? ?? false,
      lowToner: json['lowToner'] as bool? ?? false,
      noToner: json['noToner'] as bool? ?? false,
      doorOpen: json['doorOpen'] as bool? ?? false,
      spoolerJobsQueued: (json['spoolerJobsQueued'] as num?)?.toInt(),
      spoolerJobsPrinting: (json['spoolerJobsPrinting'] as num?)?.toInt(),
      spoolerLatestJobId: (json['spoolerLatestJobId'] as num?)?.toInt(),
      spoolerLatestJobStatus: json['spoolerLatestJobStatus'] as String?,
      lastErrorCode: json['lastErrorCode'] as String?,
      lastErrorAt: json['lastErrorAt'] as String?,
    );
  }

  static const unknown = PrinterHealth(state: 'unknown', online: false);
}

/// Mirrors RFC 2790 first-octet decode for Dart-side unit tests / docs.
class BrotherErrorFlagDecode {
  static Map<String, bool> fromHex(String? hex) {
    if (hex == null || hex.isEmpty) {
      return {
        'noPaper': false,
        'jammed': false,
        'offlineBit': false,
      };
    }
    final value = int.tryParse(hex.length >= 2 ? hex.substring(0, 2) : hex, radix: 16) ?? 0;
    return {
      'noPaper': (value & 0x40) != 0,
      'jammed': (value & 0x04) != 0,
      'offlineBit': (value & 0x02) != 0,
      'lowPaper': (value & 0x80) != 0,
      'lowToner': (value & 0x20) != 0,
      'noToner': (value & 0x10) != 0,
      'doorOpen': (value & 0x08) != 0,
    };
  }
}
