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

class PrinterMaintenanceToner {
  const PrinterMaintenanceToner({
    this.blackPercent,
    this.cyanPercent,
    this.magentaPercent,
    this.yellowPercent,
  });

  final int? blackPercent;
  final int? cyanPercent;
  final int? magentaPercent;
  final int? yellowPercent;

  Map<String, dynamic> toJson() => {
        if (blackPercent != null) 'blackPercent': blackPercent,
        if (cyanPercent != null) 'cyanPercent': cyanPercent,
        if (magentaPercent != null) 'magentaPercent': magentaPercent,
        if (yellowPercent != null) 'yellowPercent': yellowPercent,
      };

  factory PrinterMaintenanceToner.fromJson(Map<dynamic, dynamic> json) {
    return PrinterMaintenanceToner(
      blackPercent: (json['blackPercent'] as num?)?.toInt(),
      cyanPercent: (json['cyanPercent'] as num?)?.toInt(),
      magentaPercent: (json['magentaPercent'] as num?)?.toInt(),
      yellowPercent: (json['yellowPercent'] as num?)?.toInt(),
    );
  }
}

class PrinterMaintenancePages {
  const PrinterMaintenancePages({
    this.total,
    this.color,
    this.blackAndWhite,
  });

  final int? total;
  final int? color;
  final int? blackAndWhite;

  Map<String, dynamic> toJson() => {
        if (total != null) 'total': total,
        if (color != null) 'color': color,
        if (blackAndWhite != null) 'blackAndWhite': blackAndWhite,
      };

  factory PrinterMaintenancePages.fromJson(Map<dynamic, dynamic> json) {
    return PrinterMaintenancePages(
      total: (json['total'] as num?)?.toInt(),
      color: (json['color'] as num?)?.toInt(),
      blackAndWhite: (json['blackAndWhite'] as num?)?.toInt(),
    );
  }
}

class PrinterMaintenanceParts {
  const PrinterMaintenanceParts({
    this.beltRemainingPages,
    this.fuserRemainingPages,
  });

  final int? beltRemainingPages;
  final int? fuserRemainingPages;

  Map<String, dynamic> toJson() => {
        if (beltRemainingPages != null) 'beltRemainingPages': beltRemainingPages,
        if (fuserRemainingPages != null) 'fuserRemainingPages': fuserRemainingPages,
      };

  factory PrinterMaintenanceParts.fromJson(Map<dynamic, dynamic> json) {
    return PrinterMaintenanceParts(
      beltRemainingPages: (json['beltRemainingPages'] as num?)?.toInt(),
      fuserRemainingPages: (json['fuserRemainingPages'] as num?)?.toInt(),
    );
  }
}

/// Verified Brother private maintenance tags. Absent fields are unread, not zero.
class PrinterMaintenance {
  const PrinterMaintenance({
    required this.available,
    this.toner,
    this.pages,
    this.parts,
  });

  final bool available;
  final PrinterMaintenanceToner? toner;
  final PrinterMaintenancePages? pages;
  final PrinterMaintenanceParts? parts;

  Map<String, dynamic> toJson() {
    final tonerJson = toner?.toJson();
    final pagesJson = pages?.toJson();
    final partsJson = parts?.toJson();
    return {
      'available': available,
      if (tonerJson != null && tonerJson.isNotEmpty) 'toner': tonerJson,
      if (pagesJson != null && pagesJson.isNotEmpty) 'pages': pagesJson,
      if (partsJson != null && partsJson.isNotEmpty) 'parts': partsJson,
    };
  }

  factory PrinterMaintenance.fromJson(Map<dynamic, dynamic> json) {
    final tonerRaw = json['toner'];
    final pagesRaw = json['pages'];
    final partsRaw = json['parts'];
    return PrinterMaintenance(
      available: json['available'] == true,
      toner: tonerRaw is Map
          ? PrinterMaintenanceToner.fromJson(tonerRaw)
          : null,
      pages: pagesRaw is Map
          ? PrinterMaintenancePages.fromJson(pagesRaw)
          : null,
      parts: partsRaw is Map
          ? PrinterMaintenanceParts.fromJson(partsRaw)
          : null,
    );
  }
}

class PrinterErrorHistoryEntry {
  const PrinterErrorHistoryEntry({
    required this.index,
    required this.description,
  });

  final int index;
  final String description;

  Map<String, dynamic> toJson() => {
        'index': index,
        'description': description,
      };

  factory PrinterErrorHistoryEntry.fromJson(Map<dynamic, dynamic> json) {
    return PrinterErrorHistoryEntry(
      index: (json['index'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
    );
  }
}

/// Non-empty Brother error-history descriptions. A missing block is unread.
class PrinterErrorHistory {
  const PrinterErrorHistory({
    required this.available,
    this.entries = const [],
  });

  final bool available;
  final List<PrinterErrorHistoryEntry> entries;

  Map<String, dynamic> toJson() => {
        'available': available,
        if (entries.isNotEmpty) 'entries': entries.map((entry) => entry.toJson()).toList(),
      };

  factory PrinterErrorHistory.fromJson(Map<dynamic, dynamic> json) {
    final raw = json['entries'];
    return PrinterErrorHistory(
      available: json['available'] == true,
      entries: raw is List
          ? raw
              .whereType<Map>()
              .map((entry) => PrinterErrorHistoryEntry.fromJson(entry))
              .where((entry) => entry.index > 0 && entry.description.isNotEmpty)
              .toList()
          : const [],
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
    this.maintenance,
    this.errorHistory,
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
  final PrinterMaintenance? maintenance;
  final PrinterErrorHistory? errorHistory;
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

  /// Fatal for blocking a new print. Offline bit alone is not fatal.
  bool get isFatal => isPhysicalFatal;

  /// Jam, paper-out, spooler offline, or a hard error.
  bool get isPhysicalFatal {
    if (state == 'jam' || jammed) return true;
    if (state == 'paper_out' || noPaper) return true;
    if (state == 'error') return true;
    if (state == 'offline' && online == false) return true;
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
    if (lastErrorCode == 'USB_PRINTER_NOT_FOUND') {
      return 'USB printer was not found. Check the USB cable and that the Brother queue uses a USB port.';
    }
    if (state == 'offline') {
      return 'Printer is offline — check power and the USB cable.';
    }
    if (state == 'error') {
      return 'Printer error — check the device panel.';
    }
    if (isBusy) {
      return 'Printer is busy…';
    }
    return 'Printer ready';
  }

  /// SNMP jam and paper flags are not part of the USB detail card.
  PrinterHealth withoutSnmpFaultFlags() {
    if (!noPaper && !jammed) return this;
    return PrinterHealth(
      state: state,
      online: online,
      printerName: printerName,
      model: model,
      trays: trays,
      supplies: supplies,
      maintenance: maintenance,
      errorHistory: errorHistory,
      pageCounter: pageCounter,
      snmpOk: snmpOk,
      snmpReachable: snmpReachable,
      snmpConfigured: snmpConfigured,
      consecutiveFailures: consecutiveFailures,
      lastSuccessAtMs: lastSuccessAtMs,
      lastAttemptAtMs: lastAttemptAtMs,
      lastPollError: lastPollError,
      hrPrinterStatus: hrPrinterStatus,
      hrPrinterStatusLabel: hrPrinterStatusLabel,
      errorFlagsHex: errorFlagsHex,
      offlineBit: offlineBit,
      lowPaper: lowPaper,
      lowToner: lowToner,
      noToner: noToner,
      doorOpen: doorOpen,
      spoolerJobsQueued: spoolerJobsQueued,
      spoolerJobsPrinting: spoolerJobsPrinting,
      spoolerLatestJobId: spoolerLatestJobId,
      spoolerLatestJobStatus: spoolerLatestJobStatus,
      lastErrorCode: lastErrorCode,
      lastErrorAt: lastErrorAt,
    );
  }

  /// Ready, sleep, wait, or printing from USB. Online stays as it was.
  PrinterHealth withActivityState(String nextState) {
    if (state == nextState && !noPaper && !jammed) return this;
    return PrinterHealth(
      state: nextState,
      online: online,
      printerName: printerName,
      model: model,
      trays: trays,
      supplies: supplies,
      maintenance: maintenance,
      errorHistory: errorHistory,
      pageCounter: pageCounter,
      snmpOk: snmpOk,
      snmpReachable: snmpReachable,
      snmpConfigured: snmpConfigured,
      consecutiveFailures: consecutiveFailures,
      lastSuccessAtMs: lastSuccessAtMs,
      lastAttemptAtMs: lastAttemptAtMs,
      lastPollError: lastPollError,
      hrPrinterStatus: hrPrinterStatus,
      hrPrinterStatusLabel: hrPrinterStatusLabel,
      errorFlagsHex: errorFlagsHex,
      offlineBit: offlineBit,
      lowPaper: lowPaper,
      lowToner: lowToner,
      noToner: noToner,
      doorOpen: doorOpen,
      spoolerJobsQueued: spoolerJobsQueued,
      spoolerJobsPrinting: spoolerJobsPrinting,
      spoolerLatestJobId: spoolerLatestJobId,
      spoolerLatestJobStatus: spoolerLatestJobStatus,
      lastErrorCode: lastErrorCode,
      lastErrorAt: lastErrorAt,
    );
  }

  /// Tray 1 USB paper-out. SNMP jam does not stay. Online is unchanged.
  PrinterHealth withPaperOut() {
    return PrinterHealth(
      state: 'paper_out',
      online: online,
      printerName: printerName,
      model: model,
      trays: trays,
      supplies: supplies,
      maintenance: maintenance,
      errorHistory: errorHistory,
      pageCounter: pageCounter,
      snmpOk: snmpOk,
      snmpReachable: snmpReachable,
      snmpConfigured: snmpConfigured,
      consecutiveFailures: consecutiveFailures,
      lastSuccessAtMs: lastSuccessAtMs,
      lastAttemptAtMs: lastAttemptAtMs,
      lastPollError: lastPollError,
      hrPrinterStatus: hrPrinterStatus,
      hrPrinterStatusLabel: hrPrinterStatusLabel,
      errorFlagsHex: errorFlagsHex,
      noPaper: true,
      jammed: false,
      offlineBit: offlineBit,
      lowPaper: lowPaper,
      lowToner: lowToner,
      noToner: noToner,
      doorOpen: doorOpen,
      spoolerJobsQueued: spoolerJobsQueued,
      spoolerJobsPrinting: spoolerJobsPrinting,
      spoolerLatestJobId: spoolerLatestJobId,
      spoolerLatestJobStatus: spoolerLatestJobStatus,
      lastErrorCode: 'PAPER_OUT',
      lastErrorAt: lastErrorAt,
    );
  }

  /// USB toner, pages, and parts only. SNMP supplies and trays are dropped.
  PrinterHealth withUsbMaintenance({
    int? blackPercent,
    int? cyanPercent,
    int? magentaPercent,
    int? yellowPercent,
    int? pagesTotal,
    int? pagesColor,
    int? pagesBlackAndWhite,
    int? beltRemainingPages,
    int? fuserRemainingPages,
  }) {
    return PrinterHealth(
      state: state,
      online: online,
      printerName: printerName,
      model: model,
      trays: const [],
      supplies: const [],
      maintenance: PrinterMaintenance(
        available: true,
        toner: PrinterMaintenanceToner(
          blackPercent: blackPercent,
          cyanPercent: cyanPercent,
          magentaPercent: magentaPercent,
          yellowPercent: yellowPercent,
        ),
        pages: PrinterMaintenancePages(
          total: pagesTotal,
          color: pagesColor,
          blackAndWhite: pagesBlackAndWhite,
        ),
        parts: PrinterMaintenanceParts(
          beltRemainingPages: beltRemainingPages,
          fuserRemainingPages: fuserRemainingPages,
        ),
      ),
      errorHistory: errorHistory,
      pageCounter: pageCounter,
      snmpOk: snmpOk,
      snmpReachable: snmpReachable,
      snmpConfigured: snmpConfigured,
      consecutiveFailures: consecutiveFailures,
      lastSuccessAtMs: lastSuccessAtMs,
      lastAttemptAtMs: lastAttemptAtMs,
      lastPollError: lastPollError,
      hrPrinterStatus: hrPrinterStatus,
      hrPrinterStatusLabel: hrPrinterStatusLabel,
      errorFlagsHex: errorFlagsHex,
      noPaper: noPaper,
      jammed: jammed,
      offlineBit: offlineBit,
      lowPaper: lowPaper,
      lowToner: lowToner,
      noToner: noToner,
      doorOpen: doorOpen,
      spoolerJobsQueued: spoolerJobsQueued,
      spoolerJobsPrinting: spoolerJobsPrinting,
      spoolerLatestJobId: spoolerLatestJobId,
      spoolerLatestJobStatus: spoolerLatestJobStatus,
      lastErrorCode: lastErrorCode,
      lastErrorAt: lastErrorAt,
    );
  }

  /// Drops an SNMP error list before the first full USB history read.
  PrinterHealth withoutErrorHistory() {
    if (errorHistory == null) return this;
    return PrinterHealth(
      state: state,
      online: online,
      printerName: printerName,
      model: model,
      trays: trays,
      supplies: supplies,
      maintenance: maintenance,
      pageCounter: pageCounter,
      snmpOk: snmpOk,
      snmpReachable: snmpReachable,
      snmpConfigured: snmpConfigured,
      consecutiveFailures: consecutiveFailures,
      lastSuccessAtMs: lastSuccessAtMs,
      lastAttemptAtMs: lastAttemptAtMs,
      lastPollError: lastPollError,
      hrPrinterStatus: hrPrinterStatus,
      hrPrinterStatusLabel: hrPrinterStatusLabel,
      errorFlagsHex: errorFlagsHex,
      noPaper: noPaper,
      jammed: jammed,
      offlineBit: offlineBit,
      lowPaper: lowPaper,
      lowToner: lowToner,
      noToner: noToner,
      doorOpen: doorOpen,
      spoolerJobsQueued: spoolerJobsQueued,
      spoolerJobsPrinting: spoolerJobsPrinting,
      spoolerLatestJobId: spoolerLatestJobId,
      spoolerLatestJobStatus: spoolerLatestJobStatus,
      lastErrorCode: lastErrorCode,
      lastErrorAt: lastErrorAt,
    );
  }

  /// A full USB history replaces the SNMP list. An empty list clears it.
  PrinterHealth withUsbErrorHistory(List<PrinterErrorHistoryEntry> entries) {
    return PrinterHealth(
      state: state,
      online: online,
      printerName: printerName,
      model: model,
      trays: trays,
      supplies: supplies,
      maintenance: maintenance,
      errorHistory: PrinterErrorHistory(available: true, entries: entries),
      pageCounter: pageCounter,
      snmpOk: snmpOk,
      snmpReachable: snmpReachable,
      snmpConfigured: snmpConfigured,
      consecutiveFailures: consecutiveFailures,
      lastSuccessAtMs: lastSuccessAtMs,
      lastAttemptAtMs: lastAttemptAtMs,
      lastPollError: lastPollError,
      hrPrinterStatus: hrPrinterStatus,
      hrPrinterStatusLabel: hrPrinterStatusLabel,
      errorFlagsHex: errorFlagsHex,
      noPaper: noPaper,
      jammed: jammed,
      offlineBit: offlineBit,
      lowPaper: lowPaper,
      lowToner: lowToner,
      noToner: noToner,
      doorOpen: doorOpen,
      spoolerJobsQueued: spoolerJobsQueued,
      spoolerJobsPrinting: spoolerJobsPrinting,
      spoolerLatestJobId: spoolerLatestJobId,
      spoolerLatestJobStatus: spoolerLatestJobStatus,
      lastErrorCode: lastErrorCode,
      lastErrorAt: lastErrorAt,
    );
  }

  /// The last USB read decides whether the admin card is current.
  PrinterHealth withUsbFreshness({
    required bool lastReadOk,
    required DateTime lastSuccessAt,
  }) {
    return PrinterHealth(
      state: state,
      online: online,
      printerName: printerName,
      model: model,
      trays: trays,
      supplies: supplies,
      maintenance: maintenance,
      errorHistory: errorHistory,
      pageCounter: pageCounter,
      snmpOk: lastReadOk,
      snmpReachable: lastReadOk ? true : snmpReachable,
      snmpConfigured: snmpConfigured,
      consecutiveFailures: consecutiveFailures,
      lastSuccessAtMs: lastSuccessAt.millisecondsSinceEpoch,
      lastAttemptAtMs: lastAttemptAtMs,
      lastPollError: lastPollError,
      hrPrinterStatus: hrPrinterStatus,
      hrPrinterStatusLabel: hrPrinterStatusLabel,
      errorFlagsHex: errorFlagsHex,
      noPaper: noPaper,
      jammed: jammed,
      offlineBit: offlineBit,
      lowPaper: lowPaper,
      lowToner: lowToner,
      noToner: noToner,
      doorOpen: doorOpen,
      spoolerJobsQueued: spoolerJobsQueued,
      spoolerJobsPrinting: spoolerJobsPrinting,
      spoolerLatestJobId: spoolerLatestJobId,
      spoolerLatestJobStatus: spoolerLatestJobStatus,
      lastErrorCode: lastErrorCode,
      lastErrorAt: lastErrorAt,
    );
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
        if (maintenance != null) 'maintenance': maintenance!.toJson(),
        if (errorHistory != null) 'errorHistory': errorHistory!.toJson(),
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
    final maintenanceRaw = json['maintenance'];
    final errorHistoryRaw = json['errorHistory'];
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
      maintenance: maintenanceRaw is Map
          ? PrinterMaintenance.fromJson(maintenanceRaw)
          : null,
      errorHistory: errorHistoryRaw is Map
          ? PrinterErrorHistory.fromJson(errorHistoryRaw)
          : null,
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
