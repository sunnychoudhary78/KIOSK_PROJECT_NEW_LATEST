import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/features/weather/application/weather_controller.dart';

class WeatherHeaderStrip extends ConsumerWidget {
  const WeatherHeaderStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(weatherControllerProvider).snapshot;
    if (snapshot == null || !snapshot.hasDisplayableData) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (snapshot.temperatureC != null)
                _WeatherChip(
                  icon: _conditionIcon(snapshot.weatherCode),
                  label: '${snapshot.temperatureC!.round()}°',
                  tooltip: snapshot.weatherLabel ?? 'Temperature',
                ),
              if (snapshot.humidityPct != null)
                _WeatherChip(
                  icon: Icons.water_drop_outlined,
                  label: '${snapshot.humidityPct}%',
                  tooltip: 'Humidity',
                ),
              if (snapshot.windKmh != null)
                _WeatherChip(
                  icon: Icons.air,
                  label: '${snapshot.windKmh!.round()} km/h',
                  tooltip: 'Wind',
                ),
              if (snapshot.uvIndex != null)
                _WeatherChip(
                  icon: Icons.wb_sunny_outlined,
                  label: 'UV ${snapshot.uvIndex!.round()}',
                  tooltip: 'UV index',
                ),
              if (snapshot.aqi != null)
                _WeatherChip(
                  icon: Icons.air_outlined,
                  label: 'AQI ${snapshot.aqi}',
                  tooltip: snapshot.aqiLabel ?? 'Air quality',
                  tint: _aqiColor(snapshot.aqi!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _conditionIcon(int? code) {
    if (code == null) {
      return Icons.thermostat_outlined;
    }
    if (code == 0) {
      return Icons.wb_sunny_outlined;
    }
    if (code <= 2) {
      return Icons.wb_cloudy_outlined;
    }
    if (code == 3) {
      return Icons.cloud_outlined;
    }
    if (code == 45 || code == 48) {
      return Icons.cloud_queue_outlined;
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return Icons.umbrella_outlined;
    }
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      return Icons.ac_unit;
    }
    if (code >= 95) {
      return Icons.flash_on_outlined;
    }
    return Icons.thermostat_outlined;
  }

  Color _aqiColor(int aqi) {
    if (aqi <= 50) {
      return SkpColors.accent;
    }
    if (aqi <= 100) {
      return SkpColors.gold;
    }
    if (aqi <= 150) {
      return const Color(0xFFE67E22);
    }
    return SkpColors.danger;
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.tint,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? SkpColors.text;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: (tint ?? SkpColors.raised).withValues(
              alpha: tint == null ? 1 : 0.14,
            ),
            borderRadius: BorderRadius.circular(SkpTokens.radiusSm),
            border: Border.all(
              color: (tint ?? SkpColors.line).withValues(
                alpha: tint == null ? 1 : 0.45,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
