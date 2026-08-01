import 'package:skp_kiosk/features/well_being/domain/vital_kind.dart';
import 'package:skp_kiosk/features/well_being/domain/vital_metric.dart';
import 'package:skp_kiosk/features/well_being/domain/vital_quality.dart';

/// Current set of wellness metrics for the Well Being UI.
class VitalsSnapshot {
  const VitalsSnapshot({
    required this.metrics,
    this.updatedAt,
    this.statusMessage,
  });

  /// Ordered metrics for display (primary first).
  final List<VitalMetric> metrics;
  final DateTime? updatedAt;
  final String? statusMessage;

  VitalMetric? metric(VitalKind kind) {
    for (final m in metrics) {
      if (m.kind == kind) {
        return m;
      }
    }
    return null;
  }

  bool get hasLiveReading =>
      metrics.any((m) => m.quality == VitalQuality.live && m.hasValue);

  bool get isWaitingForFinger => metrics.any(
        (m) =>
            (m.kind == VitalKind.spo2 || m.kind == VitalKind.heartRate) &&
            m.quality == VitalQuality.waiting,
      );

  VitalsSnapshot copyWith({
    List<VitalMetric>? metrics,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    String? statusMessage,
    bool clearStatusMessage = false,
  }) {
    return VitalsSnapshot(
      metrics: metrics ?? this.metrics,
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      statusMessage:
          clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
    );
  }

  /// Default empty snapshot with SpO2, heart rate, and temperature slots.
  factory VitalsSnapshot.empty({String? statusMessage}) {
    return VitalsSnapshot(
      statusMessage: statusMessage,
      metrics: const [
        VitalMetric(
          kind: VitalKind.spo2,
          label: 'SpO₂',
          unit: '%',
        ),
        VitalMetric(
          kind: VitalKind.heartRate,
          label: 'Heart rate',
          unit: 'bpm',
        ),
        VitalMetric(
          kind: VitalKind.temperature,
          label: 'Temperature',
          unit: '°C',
        ),
      ],
    );
  }
}
