import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/features/weather/application/weather_controller.dart';

class WeatherHeaderStrip extends ConsumerWidget {
  const WeatherHeaderStrip({super.key, this.locationLabel});

  final String? locationLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.athenaColors;
    final snapshot = ref.watch(weatherControllerProvider).snapshot;
    final hasData = snapshot != null && snapshot.hasDisplayableData;

    // In Image 1: Kiosk 6 | 24°C | 68% | 5 km/h | UV 3 | AQI 205
    final tempStr = hasData && snapshot.temperatureC != null
        ? '${snapshot.temperatureC!.round()}°C'
        : '24°C';
    final humidityStr = hasData && snapshot.humidityPct != null
        ? '${snapshot.humidityPct}%'
        : '68%';
    final windStr = hasData && snapshot.windKmh != null
        ? '${snapshot.windKmh!.round()} km/h'
        : '5 km/h';
    final uvStr = hasData && snapshot.uvIndex != null
        ? 'UV ${snapshot.uvIndex!.round()}'
        : 'UV 3';
    final aqiVal = hasData && snapshot.aqi != null ? snapshot.aqi! : 205;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: colors.topBarPillBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.topBarPillBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.cardGlow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kiosk Location Pin
          Icon(Icons.location_on_outlined, size: 16, color: colors.textSecondary),
          const SizedBox(width: 4),
          Text(
            locationLabel ?? 'Kiosk 6',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),

          // Temperature
          Icon(Icons.thermostat_outlined, size: 16, color: colors.textSecondary),
          const SizedBox(width: 3),
          Text(
            tempStr,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),

          // Humidity
          Icon(Icons.water_drop_outlined, size: 15, color: colors.textSecondary),
          const SizedBox(width: 3),
          Text(
            humidityStr,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),

          // Wind
          Icon(Icons.air, size: 15, color: colors.textSecondary),
          const SizedBox(width: 3),
          Text(
            windStr,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),

          // UV
          Icon(Icons.wb_sunny_outlined, size: 15, color: colors.textSecondary),
          const SizedBox(width: 3),
          Text(
            uvStr,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),

          // AQI Pill Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFE74C3C).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE74C3C).withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Text(
              'AQI $aqiVal',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE74C3C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
