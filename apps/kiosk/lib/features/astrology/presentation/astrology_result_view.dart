import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';

/// Cinematic gold-accented reading reveal for the Astrology result phase.
class AstrologyResultView extends StatefulWidget {
  const AstrologyResultView({super.key, required this.reading});

  final AstrologyReading reading;

  @override
  State<AstrologyResultView> createState() => _AstrologyResultViewState();
}

class _AstrologyResultViewState extends State<AstrologyResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _slot(double start, double end) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final chartTiles = <_ChartTileData>[
      if (reading.chart.lagna != null)
        _ChartTileData(
          label: 'Lagna',
          value: reading.chart.lagna!,
          icon: Icons.auto_awesome,
        ),
      if (reading.chart.sunSign != null)
        _ChartTileData(
          label: 'Sun',
          value: reading.chart.sunSign!,
          icon: Icons.wb_sunny_outlined,
        ),
      if (reading.chart.moonSign != null)
        _ChartTileData(
          label: 'Moon',
          value: reading.chart.moonSign!,
          icon: Icons.nightlight_round,
        ),
      if (reading.chart.nakshatra != null)
        _ChartTileData(
          label: 'Nakshatra',
          value: reading.chart.nakshatra!,
          icon: Icons.star_outline_rounded,
        ),
      if (reading.chart.currentDasha != null)
        _ChartTileData(
          label: 'Dasha',
          value: reading.chart.currentDasha!,
          icon: Icons.timelapse_outlined,
        ),
    ];

    final palmLines = <_PalmLineData>[
      if (reading.palm.lifeLine.trim().isNotEmpty)
        _PalmLineData(
          title: 'Life line',
          body: reading.palm.lifeLine,
          icon: Icons.favorite_border,
        ),
      if (reading.palm.heartLine.trim().isNotEmpty)
        _PalmLineData(
          title: 'Heart line',
          body: reading.palm.heartLine,
          icon: Icons.favorite,
        ),
      if (reading.palm.headLine.trim().isNotEmpty)
        _PalmLineData(
          title: 'Head line',
          body: reading.palm.headLine,
          icon: Icons.psychology_outlined,
        ),
      if (reading.palm.fateLine.trim().isNotEmpty)
        _PalmLineData(
          title: 'Fate line',
          body: reading.palm.fateLine,
          icon: Icons.timeline,
        ),
    ];

    final lifeSections = <_LifeSectionData>[
      if (reading.sections.personality.trim().isNotEmpty)
        _LifeSectionData(
          title: 'Personality',
          body: reading.sections.personality,
          icon: Icons.person_outline,
        ),
      if (reading.sections.career.trim().isNotEmpty)
        _LifeSectionData(
          title: 'Career',
          body: reading.sections.career,
          icon: Icons.work_outline,
        ),
      if (reading.sections.health.trim().isNotEmpty)
        _LifeSectionData(
          title: 'Health',
          body: reading.sections.health,
          icon: Icons.health_and_safety_outlined,
        ),
      if (reading.sections.relationships.trim().isNotEmpty)
        _LifeSectionData(
          title: 'Relationships',
          body: reading.sections.relationships,
          icon: Icons.diversity_1_outlined,
        ),
      if (reading.sections.period.trim().isNotEmpty)
        _LifeSectionData(
          title: 'This period',
          body: reading.sections.period,
          icon: Icons.calendar_month_outlined,
        ),
    ];

    final title = reading.name.isEmpty
        ? 'Your reading'
        : "${reading.name}'s reading";

    var staggerIndex = 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: _CosmicBackdrop()),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              children: [
                _Reveal(
                  animation: _slot(0.0, 0.45),
                  child: _HeroHeader(
                    title: title,
                    disclaimer: reading.disclaimer,
                  ),
                ),
                if (chartTiles.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _Reveal(
                    animation: _slot(0.12, 0.55),
                    child: _ChartConstellation(tiles: chartTiles),
                  ),
                ],
                if (reading.sections.overview.trim().isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _Reveal(
                    animation: _slot(0.22, 0.62),
                    child: _OverviewSpotlight(body: reading.sections.overview),
                  ),
                ],
                if (reading.palm.summary.trim().isNotEmpty ||
                    palmLines.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  _Reveal(
                    animation: _slot(0.28, 0.68),
                    child: _SectionEyebrow(
                      icon: Icons.back_hand_outlined,
                      label: 'Palm insights',
                    ),
                  ),
                  if (reading.palm.summary.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _StaggerItem(
                      index: staggerIndex++,
                      parent: _entrance,
                      child: _PalmSummaryBanner(summary: reading.palm.summary),
                    ),
                  ],
                  if (palmLines.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _PalmLinesGrid(
                      lines: palmLines,
                      parent: _entrance,
                      startIndex: staggerIndex,
                    ),
                  ],
                ],
                if (lifeSections.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _Reveal(
                    animation: _slot(0.38, 0.75),
                    child: const _SectionEyebrow(
                      icon: Icons.explore_outlined,
                      label: 'Life path',
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < lifeSections.length; i++)
                    _StaggerItem(
                      index: staggerIndex + palmLines.length + i,
                      parent: _entrance,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LifePathCard(section: lifeSections[i]),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _StaggerItem extends StatelessWidget {
  const _StaggerItem({
    required this.index,
    required this.parent,
    required this.child,
  });

  final int index;
  final AnimationController parent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (0.35 + index * 0.06).clamp(0.0, 0.85);
    final end = (start + 0.22).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: parent,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return _Reveal(animation: animation, child: child);
  }
}

class _CosmicBackdrop extends StatelessWidget {
  const _CosmicBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.55),
          radius: 1.15,
          colors: [
            SkpColors.gold.withValues(alpha: 0.14),
            SkpColors.accent.withValues(alpha: 0.10),
            SkpColors.canvas.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: const CustomPaint(
        painter: _StarFieldPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    final count = (size.width * size.height / 14000).clamp(28, 70).toInt();
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() * 1.4 + 0.4;
      final goldish = rnd.nextBool();
      paint.color = (goldish ? SkpColors.gold : SkpColors.text)
          .withValues(alpha: 0.08 + rnd.nextDouble() * 0.18);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.title, required this.disclaimer});

  final String title;
  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Your stars have spoken',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: SkpColors.gold,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: SkpColors.text,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 14),
        const _GoldUnderline(),
        const SizedBox(height: 14),
        Text(
          'A personal glimpse of chart and palm — for wonder, not worry.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
        ),
        const SizedBox(height: 10),
        Text(
          disclaimer,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: SkpColors.muted.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _GoldUnderline extends StatelessWidget {
  const _GoldUnderline();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Center(
          child: Container(
            width: 120 * t,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [
                  SkpColors.gold.withValues(alpha: 0.15),
                  SkpColors.gold.withValues(alpha: 0.35 + 0.65 * t),
                  SkpColors.gold.withValues(alpha: 0.15),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: SkpColors.gold.withValues(alpha: 0.35 * t),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChartTileData {
  const _ChartTileData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _ChartConstellation extends StatelessWidget {
  const _ChartConstellation({required this.tiles});

  final List<_ChartTileData> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 720
            ? math.min(tiles.length, 5)
            : width >= 520
                ? math.min(tiles.length, 3)
                : 2;
        final gap = 10.0;
        final tileW = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileW,
                child: _ChartMetricTile(data: tile),
              ),
          ],
        );
      },
    );
  }
}

class _ChartMetricTile extends StatelessWidget {
  const _ChartMetricTile({required this.data});

  final _ChartTileData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: SkpColors.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        border: Border.all(color: SkpColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: SkpColors.gold, size: 26),
          const SizedBox(height: 10),
          Text(
            data.label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: SkpColors.gold,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: SkpColors.text,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewSpotlight extends StatelessWidget {
  const _OverviewSpotlight({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: SkpColors.panel,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        border: Border.all(color: SkpColors.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: SkpColors.gold,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(SkpTokens.radiusLg),
                  bottomLeft: Radius.circular(SkpTokens.radiusLg),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OVERVIEW',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: SkpColors.gold,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: SkpColors.text,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: SkpColors.gold, size: 22),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: SkpColors.gold,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _PalmSummaryBanner extends StatelessWidget {
  const _PalmSummaryBanner({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SkpColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        border: Border.all(color: SkpColors.accentBright.withValues(alpha: 0.35)),
      ),
      child: Text(
        summary,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: SkpColors.text,
              height: 1.4,
            ),
      ),
    );
  }
}

class _PalmLineData {
  const _PalmLineData({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}

class _PalmLinesGrid extends StatelessWidget {
  const _PalmLinesGrid({
    required this.lines,
    required this.parent,
    required this.startIndex,
  });

  final List<_PalmLineData> lines;
  final AnimationController parent;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 12.0;
        final tileW = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < lines.length; i++)
              SizedBox(
                width: tileW,
                child: _StaggerItem(
                  index: startIndex + i,
                  parent: parent,
                  child: _PalmLineCard(data: lines[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PalmLineCard extends StatelessWidget {
  const _PalmLineCard({required this.data});

  final _PalmLineData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SkpColors.panel,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        border: Border.all(color: SkpColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SkpColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: SkpColors.gold, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: SkpColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: SkpColors.text,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifeSectionData {
  const _LifeSectionData({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}

class _LifePathCard extends StatelessWidget {
  const _LifePathCard({required this.section});

  final _LifeSectionData section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SkpColors.panel.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        border: Border.all(color: SkpColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SkpColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: SkpColors.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(section.icon, color: SkpColors.gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: SkpColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            section.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: SkpColors.text,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
