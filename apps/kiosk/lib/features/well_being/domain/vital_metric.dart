import 'package:skp_kiosk/features/well_being/domain/vital_kind.dart';
import 'package:skp_kiosk/features/well_being/domain/vital_quality.dart';

/// One displayable vital measurement.
class VitalMetric {
  const VitalMetric({
    required this.kind,
    required this.label,
    required this.unit,
    this.value,
    this.quality = VitalQuality.unknown,
  });

  final VitalKind kind;
  final String label;
  final String unit;
  final double? value;
  final VitalQuality quality;

  bool get hasValue => value != null;

  String get displayValue {
    if (value == null) {
      return '—';
    }
    if (kind == VitalKind.heartRate || kind == VitalKind.spo2) {
      return value!.round().toString();
    }
    return value!.toStringAsFixed(1);
  }

  VitalMetric copyWith({
    double? value,
    bool clearValue = false,
    VitalQuality? quality,
  }) {
    return VitalMetric(
      kind: kind,
      label: label,
      unit: unit,
      value: clearValue ? null : (value ?? this.value),
      quality: quality ?? this.quality,
    );
  }
}
