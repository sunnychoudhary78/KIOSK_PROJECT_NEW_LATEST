import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
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
    final width = MediaQuery.sizeOf(context).width;
    final dense = width < 1180;
    final compact = width < 980;

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

    Widget metric(IconData icon, String value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 14 : 16, color: colors.textSecondary),
          SizedBox(width: dense ? 2 : 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: dense ? 13 : 15,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ],
      );
    }

    return Container(
      height: dense ? 36 : 42,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 14,
        vertical: dense ? 3 : 5,
      ),
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
          Icon(
            Icons.location_on_outlined,
            size: dense ? 14 : 16,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              locationLabel ?? 'Kiosk 6',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: dense ? 13 : 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          SizedBox(width: dense ? 8 : 10),
          metric(Icons.thermostat_outlined, tempStr),
          if (!compact) ...[
            SizedBox(width: dense ? 8 : 10),
            metric(Icons.water_drop_outlined, humidityStr),
          ],
          if (!dense) ...[
            const SizedBox(width: 10),
            metric(Icons.air, windStr),
            const SizedBox(width: 10),
            metric(Icons.wb_sunny_outlined, uvStr),
          ],
          SizedBox(width: dense ? 8 : 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.airQuality),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 6 : 7,
                  vertical: dense ? 2 : 2.5,
                ),
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
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: dense ? 12 : 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE74C3C),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
