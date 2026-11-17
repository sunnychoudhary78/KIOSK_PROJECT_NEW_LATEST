import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';
import 'package:skp_kiosk/features/weather/application/air_quality_controller.dart';
import 'package:skp_kiosk/features/weather/domain/air_quality_detail.dart';

class AirQualityPage extends ConsumerStatefulWidget {
  const AirQualityPage({super.key});

  @override
  ConsumerState<AirQualityPage> createState() => _AirQualityPageState();
}

class _AirQualityPageState extends ConsumerState<AirQualityPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(airQualityControllerProvider.notifier).load();
    });
  }

  Future<void> _endSession() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(airQualityControllerProvider);
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'Air Quality',
        titleIcon: Icons.air_rounded,
        onHome: _endSession,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your local air quality report',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _AirQualityBody(
                  state: state,
                  colors: colors,
                  isDark: isDark,
                  onRetry: () =>
                      ref.read(airQualityControllerProvider.notifier).load(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(26),
                    child: Ink(
                      height: 40,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1C143F)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF7445BD)
                              : const Color(0xFFD0D5DD),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: colors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AirQualityBody extends StatelessWidget {
  const _AirQualityBody({
    required this.state,
    required this.colors,
    required this.isDark,
    required this.onRetry,
  });

  final AirQualityUiState state;
  final AthenaColors colors;
  final bool isDark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.detail == null) {
      return const Center(
        child: KioskLoading(message: 'Loading air quality…'),
      );
    }

    if (state.error != null && state.detail == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KioskStatusBanner(
            tone: KioskBannerTone.danger,
            message: state.error!,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: KioskGhostButton(label: 'Try again', onPressed: onRetry),
          ),
        ],
      );
    }

    final detail = state.detail;
    if (detail == null) {
      return const KioskEmpty(
        message: 'We could not load a local AQI reading right now.',
      );
    }

    final pm25 = detail.pollutantByCode('pm25') ??
        detail.pollutantByCode('pm2.5') ??
        detail.pollutantByCode('pm2_5');
    final pm10 = detail.pollutantByCode('pm10');
    final advice =
        detail.healthRecommendations?.generalPopulation?.trim().isNotEmpty ==
                true
            ? detail.healthRecommendations!.generalPopulation!.trim()
            : _fallbackAdvice(detail.aqiLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.error != null) ...[
          KioskStatusBanner(
            tone: KioskBannerTone.danger,
            message: state.error!,
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          flex: 5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _AqiHeroCard(detail: detail, colors: colors),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _PollutantCard(
                              label: 'PM2.5',
                              pollutant: pm25,
                              colors: colors,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PollutantCard(
                              label: 'PM10',
                              pollutant: pm10,
                              colors: colors,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _AdviceCard(
                        advice: advice,
                        colors: colors,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'AQI history (24h)',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 5,
          child: _HistorySection(
            state: state,
            colors: colors,
          ),
        ),
      ],
    );
  }
}

class _AqiHeroCard extends StatelessWidget {
  const _AqiHeroCard({required this.detail, required this.colors});

  final AirQualityDetail detail;
  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    final bandColor = _bandColor(detail);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: bandColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bandColor.withValues(alpha: 0.95), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: bandColor.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LOCAL AQI',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  detail.updatedAt != null ? 'LIVE' : 'AQI',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            detail.aqi?.toString() ?? '--',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 52,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (detail.aqiLabel ?? 'Unknown').toUpperCase(),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (detail.dominantPollutant != null) ...[
            const SizedBox(height: 4),
            Text(
              'Dominant: ${detail.dominantPollutant}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PollutantCard extends StatelessWidget {
  const _PollutantCard({
    required this.label,
    required this.pollutant,
    required this.colors,
  });

  final String label;
  final AirQualityPollutant? pollutant;
  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    final valueText = _formatConcentration(pollutant?.concentration);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.cardGlow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valueText,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice, required this.colors});

  final String advice;
  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What should you do today?',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              advice,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.state,
    required this.colors,
  });

  final AirQualityUiState state;
  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    if (state.historyLoading && state.history == null) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.cardBorder),
        ),
        child: const KioskLoading(message: 'Loading history…'),
      );
    }

    if (state.historyError != null &&
        (state.history == null || state.history!.points.isEmpty)) {
      return KioskStatusBanner(
        tone: KioskBannerTone.danger,
        message: state.historyError!,
      );
    }

    final points = state.history?.points
            .where((p) => p.aqi != null)
            .toList(growable: false) ??
        const <AirQualityHistoryPoint>[];

    if (points.isEmpty) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Text(
          'No history available for the last 24 hours.',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            color: colors.textSecondary,
          ),
        ),
      );
    }

    final values = points.map((p) => p.aqi!.toDouble()).toList();
    final minAqi = values.reduce(math.min);
    final maxAqi = values.reduce(math.max);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CustomPaint(
              painter: _AqiHistoryPainter(
                values: values,
                lineColor: colors.accentCyan,
                fillColor: colors.accentCyan.withValues(alpha: 0.18),
                gridColor: colors.cardBorder,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Low ${minAqi.round()}',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'High ${maxAqi.round()}',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AqiHistoryPainter extends CustomPainter {
  _AqiHistoryPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);

    Offset pointAt(int index) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * (index / (values.length - 1));
      final normalized = (values[index] - minV) / span;
      final y = size.height - (normalized * size.height);
      return Offset(x, y);
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = lineColor;
    for (var i = 0; i < values.length; i++) {
      if (i == 0 || i == values.length - 1 || i % 4 == 0) {
        canvas.drawCircle(pointAt(i), 3.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AqiHistoryPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor;
  }
}

Color _bandColor(AirQualityDetail detail) {
  final fromApi = detail.color;
  if (fromApi != null) {
    return Color.fromARGB(255, fromApi.r, fromApi.g, fromApi.b);
  }
  final label = (detail.aqiLabel ?? '').toLowerCase();
  if (label.contains('good')) {
    return const Color(0xFF2ECC71);
  }
  if (label.contains('satisfactory')) {
    return const Color(0xFF27AE60);
  }
  if (label.contains('moderate')) {
    return const Color(0xFFF39C12);
  }
  if (label.contains('very poor')) {
    return const Color(0xFF8E1B3D);
  }
  if (label.contains('poor')) {
    return const Color(0xFFE74C3C);
  }
  if (label.contains('severe')) {
    return const Color(0xFF6C0F2A);
  }
  final aqi = detail.aqi ?? 0;
  if (aqi <= 50) return const Color(0xFF2ECC71);
  if (aqi <= 100) return const Color(0xFF27AE60);
  if (aqi <= 200) return const Color(0xFFF39C12);
  if (aqi <= 300) return const Color(0xFFE74C3C);
  if (aqi <= 400) return const Color(0xFF8E1B3D);
  return const Color(0xFF6C0F2A);
}

String _fallbackAdvice(String? label) {
  final key = (label ?? '').toLowerCase();
  if (key.contains('good') || key.contains('satisfactory')) {
    return 'Air quality is acceptable. Enjoy outdoor activities as usual.';
  }
  if (key.contains('moderate')) {
    return 'Sensitive groups should limit prolonged outdoor exertion.';
  }
  if (key.contains('poor') || key.contains('severe')) {
    return 'Limit prolonged outdoor exposure and follow local health guidance.';
  }
  return 'Check local advisories and follow official health guidance.';
}

String _formatConcentration(AirQualityConcentration? concentration) {
  if (concentration == null) {
    return '--';
  }
  final value = concentration.value;
  final formatted = value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(value >= 10 ? 0 : 1);
  final units = _friendlyUnits(concentration.units);
  return units.isEmpty ? formatted : '$formatted $units';
}

String _friendlyUnits(String units) {
  switch (units.trim().toUpperCase()) {
    case 'MICROGRAMS_PER_CUBIC_METER':
      return 'µg/m³';
    case 'PARTS_PER_BILLION':
      return 'ppb';
    case 'PARTS_PER_MILLION':
      return 'ppm';
    case '':
      return '';
    default:
      return units;
  }
}
