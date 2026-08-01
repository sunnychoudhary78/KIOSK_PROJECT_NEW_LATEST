import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/well_being/domain/vital_kind.dart';
import 'package:skp_kiosk/features/well_being/domain/vital_metric.dart';
import 'package:skp_kiosk/features/well_being/domain/vital_quality.dart';

/// Large or compact tile for a single vital metric.
class VitalMetricTile extends StatelessWidget {
  const VitalMetricTile({
    super.key,
    required this.metric,
    this.emphasized = false,
    this.comingSoon = false,
  });

  final VitalMetric metric;
  final bool emphasized;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final valueStyle = emphasized
        ? theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
            height: 1.05,
          )
        : theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: comingSoon
                ? scheme.onSurface.withValues(alpha: 0.35)
                : scheme.onSurface,
          );

    final labelStyle = theme.textTheme.titleMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.7),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: metric.quality == VitalQuality.stale ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(metric.label, style: labelStyle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            if (comingSoon)
              Text(
                'Coming soon',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _valueText(),
                    style: valueStyle,
                    textAlign: TextAlign.center,
                  ),
                  if (metric.hasValue) ...[
                    const SizedBox(width: 6),
                    Text(
                      metric.unit,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 6),
            Text(
              _qualityHint(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _qualityColor(scheme),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _valueText() {
    if (metric.quality == VitalQuality.waiting) {
      return '—';
    }
    return metric.displayValue;
  }

  String _qualityHint() {
    if (comingSoon) {
      return 'Sensor not installed';
    }
    return switch (metric.quality) {
      VitalQuality.unknown => 'Waiting…',
      VitalQuality.waiting => 'No finger',
      VitalQuality.live => 'Live',
      VitalQuality.stale => 'Signal lost',
    };
  }

  Color _qualityColor(ColorScheme scheme) {
    return switch (metric.quality) {
      VitalQuality.live => scheme.primary,
      VitalQuality.waiting => scheme.tertiary,
      VitalQuality.stale => scheme.error.withValues(alpha: 0.8),
      VitalQuality.unknown => scheme.onSurface.withValues(alpha: 0.45),
    };
  }
}

/// Whether the temperature slot should show the placeholder.
bool isTemperatureComingSoon(VitalMetric metric) {
  return metric.kind == VitalKind.temperature &&
      metric.quality == VitalQuality.unknown &&
      !metric.hasValue;
}
