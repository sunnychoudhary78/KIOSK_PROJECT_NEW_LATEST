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
  bool _showSensitiveAdvice = false;

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
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your local air quality report',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _AirQualityBody(
                  state: state,
                  colors: colors,
                  isDark: isDark,
                  showSensitiveAdvice: _showSensitiveAdvice,
                  onToggleSensitive: () {
                    setState(() => _showSensitiveAdvice = !_showSensitiveAdvice);
                  },
                  onRetry: () =>
                      ref.read(airQualityControllerProvider.notifier).load(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(26),
                    child: Ink(
                      height: 44,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
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
                              fontSize: 16,
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
    required this.showSensitiveAdvice,
    required this.onToggleSensitive,
    required this.onRetry,
  });

  final AirQualityUiState state;
  final AthenaColors colors;
  final bool isDark;
  final bool showSensitiveAdvice;
  final VoidCallback onToggleSensitive;
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
          const SizedBox(height: 16),
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
    final otherPollutants = detail.pollutants.where((p) {
      final code = p.code.toLowerCase();
      return code != 'pm25' &&
          code != 'pm2.5' &&
          code != 'pm2_5' &&
          code != 'pm10';
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.error != null) ...[
            KioskStatusBanner(
              tone: KioskBannerTone.danger,
              message: state.error!,
            ),
            const SizedBox(height: 12),
          ],
          _AqiHeroCard(detail: detail, colors: colors),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PollutantCard(
                  label: 'PM2.5',
                  pollutant: pm25,
                  colors: colors,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PollutantCard(
                  label: 'PM10',
                  pollutant: pm10,
                  colors: colors,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (otherPollutants.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final pollutant in otherPollutants)
                  _PollutantChip(pollutant: pollutant, colors: colors),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'What should you do today?',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail.healthRecommendations?.generalPopulation?.trim().isNotEmpty ==
                    true
                ? detail.healthRecommendations!.generalPopulation!.trim()
                : _fallbackAdvice(detail.aqiLabel),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          if (detail.healthRecommendations?.sensitiveGroups.isNotEmpty ==
              true) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onToggleSensitive,
                child: Text(
                  showSensitiveAdvice
                      ? 'Hide sensitive-group advice'
                      : 'Show sensitive-group advice',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                    color: colors.accentCyan,
                  ),
                ),
              ),
            ),
            if (showSensitiveAdvice) ...[
              const SizedBox(height: 6),
              for (final group
                  in detail.healthRecommendations!.sensitiveGroups) ...[
                _SensitiveAdviceTile(
                  label: group.$1,
                  text: group.$2,
                  colors: colors,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
          const SizedBox(height: 22),
          Text(
            'AQI history (24h)',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _HistorySection(
            state: state,
            colors: colors,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
        ],
      ),
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
    final advice = detail.healthRecommendations?.generalPopulation?.trim();
    final shortAdvice = (advice != null && advice.isNotEmpty)
        ? advice
        : _fallbackAdvice(detail.aqiLabel);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: bandColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: bandColor.withValues(alpha: 0.95), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: bandColor.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  detail.updatedAt != null ? 'LIVE DATA' : 'AQI',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detail.aqi?.toString() ?? '--',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 72,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            (detail.aqiLabel ?? 'Unknown').toUpperCase(),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (detail.dominantPollutant != null) ...[
            const SizedBox(height: 4),
            Text(
              'Dominant pollutant: ${detail.dominantPollutant}',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            shortAdvice,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
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
    required this.isDark,
  });

  final String label;
  final AirQualityPollutant? pollutant;
  final AthenaColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final valueText = _formatConcentration(pollutant?.concentration);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.cardGlow,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            valueText,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PollutantChip extends StatelessWidget {
  const _PollutantChip({required this.pollutant, required this.colors});

  final AirQualityPollutant pollutant;
  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Text(
        '${pollutant.displayName}: ${_formatConcentration(pollutant.concentration)}',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

class _SensitiveAdviceTile extends StatelessWidget {
  const _SensitiveAdviceTile({
    required this.label,
    required this.text,
    required this.colors,
    required this.isDark,
  });

  final String label;
  final String text;
  final AthenaColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.accentMagenta,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              height: 1.3,
              color: colors.textSecondary,
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
    required this.isDark,
  });

  final AirQualityUiState state;
  final AthenaColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (state.historyLoading && state.history == null) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
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
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Text(
          'No history available for the last 24 hours.',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 15,
            color: colors.textSecondary,
          ),
        ),
      );
    }

    final values = points.map((p) => p.aqi!.toDouble()).toList();
    final minAqi = values.reduce(math.min);
    final maxAqi = values.reduce(math.max);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Low $minAqi',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'High $maxAqi',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
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
