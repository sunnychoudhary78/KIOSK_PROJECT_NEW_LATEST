import 'package:skp_admin/features/printer/data/printer_display.dart';
import 'package:skp_admin/features/printer/data/printer_health.dart';

const heartbeatStale = Duration(minutes: 3);

class SurveillanceHealth {
  const SurveillanceHealth({
    this.state,
    this.queuePending,
    this.lastErrorCode,
  });

  final String? state;
  final int? queuePending;
  final String? lastErrorCode;

  factory SurveillanceHealth.fromJson(Map<String, dynamic> json) {
    final pending = json['queuePending'];
    return SurveillanceHealth(
      state: json['state'] as String?,
      queuePending: pending is num ? pending.toInt() : null,
      lastErrorCode: json['lastErrorCode'] as String?,
    );
  }
}

class RecordingDisplay {
  const RecordingDisplay({required this.label, required this.tone});

  final String label;
  final PrinterRowTone tone;
}

class KioskDevice {
  const KioskDevice({
    required this.id,
    required this.name,
    required this.deviceKey,
    required this.status,
    required this.siteName,
    required this.surveillanceEnabled,
    this.latitude,
    this.longitude,
    this.address,
    this.lastHeartbeatAt,
    this.surveillanceHealth,
    this.printerHealth,
    this.printerHealthAt,
    this.printerRefreshRequestedAt,
    this.printingPausedReason,
    this.pagesLeft,
  });

  final String id;
  final String name;
  final String deviceKey;
  final String status;
  final String siteName;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime? lastHeartbeatAt;
  final bool surveillanceEnabled;
  final SurveillanceHealth? surveillanceHealth;
  final PrinterHealth? printerHealth;
  final DateTime? printerHealthAt;
  final DateTime? printerRefreshRequestedAt;
  final String? printingPausedReason;
  final int? pagesLeft;

  String get locationLabel {
    final trimmed = address?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
    }
    return '—';
  }

  String? get printerHealthAtIso => printerHealthAt?.toUtc().toIso8601String();

  String? get printerRefreshRequestedAtIso =>
      printerRefreshRequestedAt?.toUtc().toIso8601String();

  factory KioskDevice.fromJson(Map<String, dynamic> json) {
    return KioskDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      deviceKey: json['deviceKey'] as String? ?? '',
      status: json['status'] as String? ?? '',
      siteName: json['siteName'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      lastHeartbeatAt: DateTime.tryParse(json['lastHeartbeatAt'] as String? ?? ''),
      surveillanceEnabled: json['surveillanceEnabled'] == true,
      surveillanceHealth: json['surveillanceHealth'] is Map
          ? SurveillanceHealth.fromJson(
              Map<String, dynamic>.from(json['surveillanceHealth'] as Map),
            )
          : null,
      printerHealth: json['printerHealth'] is Map
          ? PrinterHealth.fromJson(Map<String, dynamic>.from(json['printerHealth'] as Map))
          : null,
      printerHealthAt: DateTime.tryParse(json['printerHealthAt'] as String? ?? ''),
      printerRefreshRequestedAt: DateTime.tryParse(
        json['printerRefreshRequestedAt'] as String? ?? '',
      ),
      printingPausedReason: json['printingPausedReason'] as String?,
      pagesLeft: json['pagesLeft'] is num ? (json['pagesLeft'] as num).toInt() : null,
    );
  }
}

bool kioskNeedsAttention(KioskDevice device, {DateTime? now}) {
  final paused = device.printingPausedReason;
  if (paused != null && paused.isNotEmpty) return true;
  final summary = resolvePrinterRowSummary(device.printerHealth);
  if (summary.tone == PrinterRowTone.alert || summary.tone == PrinterRowTone.amber) {
    return true;
  }
  final beat = device.lastHeartbeatAt;
  if (beat == null) return true;
  return (now ?? DateTime.now()).difference(beat) > heartbeatStale;
}

RecordingDisplay resolveRecordingDisplay(KioskDevice device, {DateTime? now}) {
  if (!device.surveillanceEnabled) {
    return const RecordingDisplay(label: 'Recording off', tone: PrinterRowTone.muted);
  }
  final beat = device.lastHeartbeatAt;
  final fresh = beat != null && (now ?? DateTime.now()).difference(beat) <= heartbeatStale;
  if (!fresh) {
    return const RecordingDisplay(label: 'Recording offline', tone: PrinterRowTone.muted);
  }
  final health = device.surveillanceHealth;
  if (health == null) {
    return const RecordingDisplay(label: 'Recording unknown', tone: PrinterRowTone.amber);
  }
  return switch (health.state) {
    'recording' => const RecordingDisplay(label: 'Recording', tone: PrinterRowTone.ok),
    'uploading' => RecordingDisplay(
      label: (health.queuePending ?? 0) > 0
          ? 'Uploading (${health.queuePending})'
          : 'Uploading',
      tone: PrinterRowTone.amber,
    ),
    'paused_palm' => const RecordingDisplay(label: 'Recording paused', tone: PrinterRowTone.muted),
    'camera_error' => const RecordingDisplay(label: 'Camera error', tone: PrinterRowTone.alert),
    'storage_low' => const RecordingDisplay(label: 'Storage low', tone: PrinterRowTone.alert),
    'stale' => const RecordingDisplay(label: 'Recording stale', tone: PrinterRowTone.amber),
    'offline' => const RecordingDisplay(label: 'Recording offline', tone: PrinterRowTone.muted),
    _ => const RecordingDisplay(label: 'Recording unknown', tone: PrinterRowTone.amber),
  };
}
