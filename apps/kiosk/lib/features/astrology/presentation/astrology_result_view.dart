import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_assets.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/cosmic_backdrop.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/glass_panel.dart';

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
  int _lifeTab = 0;

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
          art: AstrologyAssets.chartArtFor(
            label: 'Lagna',
            value: reading.chart.lagna!,
          ),
        ),
      if (reading.chart.sunSign != null)
        _ChartTileData(
          label: 'Sun',
          value: reading.chart.sunSign!,
          icon: Icons.wb_sunny_outlined,
          art: AstrologyAssets.chartArtFor(
            label: 'Sun',
            value: reading.chart.sunSign!,
          ),
        ),
      if (reading.chart.moonSign != null)
        _ChartTileData(
          label: 'Moon',
          value: reading.chart.moonSign!,
          icon: Icons.nightlight_round,
          art: AstrologyAssets.chartArtFor(
            label: 'Moon',
            value: reading.chart.moonSign!,
          ),
        ),
      if (reading.chart.nakshatra != null)
        _ChartTileData(
          label: 'Nakshatra',
          value: reading.chart.nakshatra!,
          icon: Icons.star_outline_rounded,
          art: AstrologyAssets.chartArtFor(
            label: 'Nakshatra',
            value: reading.chart.nakshatra!,
          ),
        ),
      if (reading.chart.currentDasha != null)
        _ChartTileData(
          label: 'Dasha',
          value: reading.chart.currentDasha!,
          icon: Icons.timelapse_outlined,
          art: AstrologyAssets.chartArtFor(
            label: 'Dasha',
            value: reading.chart.currentDasha!,
          ),
        ),
    ];

    final palmLines = <_PalmLineData>[
      if (reading.palm.lifeLine.trim().isNotEmpty)
        _PalmLineData(
          title: 'Life line',
          body: reading.palm.lifeLine,
          icon: Icons.favorite_border,
          art: AstrologyAssets.palmLife,
        ),
      if (reading.palm.heartLine.trim().isNotEmpty)
        _PalmLineData(
          title: 'Heart line',
          body: reading.palm.heartLine,
          icon: Icons.favorite,
          art: AstrologyAssets.palmHeart,
        ),
      if (reading.palm.headLine.trim().isNotEmpty)
        _PalmLineData(
          title: 'Head line',
          body: reading.palm.headLine,
          icon: Icons.psychology_outlined,
          art: AstrologyAssets.palmHead,
        ),
      if (reading.palm.fateLine.trim().isNotEmpty)
        _PalmLineData(
          title: 'Fate line',
          body: reading.palm.fateLine,
          icon: Icons.timeline,
          art: AstrologyAssets.palmFate,
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
    final trimmedName = reading.name.trim();
    final initial = trimmedName.isEmpty
        ? '✦'
        : String.fromCharCode(trimmedName.runes.first).toUpperCase();

    var staggerIndex = 0;
    final lifeTab =
        lifeSections.isEmpty ? 0 : _lifeTab.clamp(0, lifeSections.length - 1);

    return Stack(
      fit: StackFit.expand,
      children: [
        const CosmicBackdrop(),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              children: [
                _Reveal(
                  animation: _slot(0.0, 0.45),
                  child: _HeroSeal(
                    title: title,
                    initial: initial,
                    disclaimer: reading.disclaimer,
                    orbitChips: chartTiles
                        .take(4)
                        .map(
                          (t) => _OrbitChipData(
                            label: '${t.label}: ${t.value}',
                            art: t.art,
                          ),
                        )
                        .toList(),
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
                    child: const _SectionEyebrow(
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
                  _Reveal(
                    animation: _slot(0.42, 0.82),
                    child: _LifePathTabs(
                      sections: lifeSections,
                      selected: lifeTab,
                      onSelected: (i) => setState(() => _lifeTab = i),
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

class _OrbitChipData {
  const _OrbitChipData({required this.label, this.art});

  final String label;
  final String? art;
}

class _HeroSeal extends StatelessWidget {
  const _HeroSeal({
    required this.title,
    required this.initial,
    required this.disclaimer,
    required this.orbitChips,
  });

  final String title;
  final String initial;
  final String disclaimer;
  final List<_OrbitChipData> orbitChips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 188,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < orbitChips.length; i++)
                _OrbitChip(
                  data: orbitChips[i],
                  angle: -math.pi / 2 +
                      (i * (math.pi * 2 / math.max(orbitChips.length, 1))),
                  radius: 118,
                ),
              Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AstrologyColors.gold.withValues(alpha: 0.75),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AstrologyColors.gold.withValues(alpha: 0.28),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const AstrologyAssetImage(
                        asset: AstrologyAssets.sealMedallion,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        color: AstrologyColors.canvas.withValues(alpha: 0.35),
                      ),
                      Center(
                        child: Text(
                          initial,
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: AstrologyColors.goldSoft,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(blurRadius: 8, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your stars have spoken',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AstrologyColors.gold,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AstrologyColors.text,
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
          style: theme.textTheme.bodyLarge?.copyWith(color: AstrologyColors.muted),
        ),
        const SizedBox(height: 10),
        Text(
          disclaimer,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AstrologyColors.muted.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _OrbitChip extends StatelessWidget {
  const _OrbitChip({
    required this.data,
    required this.angle,
    required this.radius,
  });

  final _OrbitChipData data;
  final double angle;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(math.cos(angle) * radius * 0.55, math.sin(angle) * radius * 0.42),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 168),
        padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
        decoration: BoxDecoration(
          color: AstrologyColors.panelSolid.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AstrologyColors.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.art != null) ...[
              ClipOval(
                child: AstrologyAssetImage(
                  asset: data.art!,
                  width: 22,
                  height: 22,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AstrologyColors.goldSoft,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
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
                  AstrologyColors.gold.withValues(alpha: 0.15),
                  AstrologyColors.gold.withValues(alpha: 0.35 + 0.65 * t),
                  AstrologyColors.gold.withValues(alpha: 0.15),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AstrologyColors.gold.withValues(alpha: 0.35 * t),
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
    this.art,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? art;
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
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      borderRadius: SkpTokens.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.art != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AstrologyAssetImage(
                asset: data.art!,
                width: 48,
                height: 48,
              ),
            )
          else
            Icon(data.icon, color: AstrologyColors.gold, size: 26),
          const SizedBox(height: 10),
          Text(
            data.label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: AstrologyColors.gold,
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
              color: AstrologyColors.text,
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
    return GlassPanel(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: AstrologyColors.gold,
                borderRadius: BorderRadius.only(
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
                        color: AstrologyColors.gold,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '“$body”',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AstrologyColors.text,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
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
        Icon(icon, color: AstrologyColors.gold, size: 22),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AstrologyColors.gold,
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
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      color: AstrologyColors.accent.withValues(alpha: 0.14),
      borderColor: AstrologyColors.accent.withValues(alpha: 0.4),
      child: Text(
        summary,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AstrologyColors.text,
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
    this.art,
  });

  final String title;
  final String body;
  final IconData icon;
  final String? art;
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
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AstrologyColors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AstrologyColors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: data.art != null
                      ? AstrologyAssetImage(
                          asset: data.art!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : Icon(data.icon, color: AstrologyColors.gold, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AstrologyColors.gold,
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
                color: AstrologyColors.text,
                height: 1.4,
              ),
            ),
          ],
        ),
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

class _LifePathTabs extends StatelessWidget {
  const _LifePathTabs({
    required this.sections,
    required this.selected,
    required this.onSelected,
  });

  final List<_LifeSectionData> sections;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final section = sections[selected];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _LifeTabChip(
                  label: sections[i].title,
                  selected: i == selected,
                  onTap: () => onSelected(i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassPanel(
          padding: const EdgeInsets.all(18),
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
                      color: AstrologyColors.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AstrologyColors.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(section.icon, color: AstrologyColors.gold, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AstrologyColors.gold,
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
                  color: AstrologyColors.text,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LifeTabChip extends StatelessWidget {
  const _LifeTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AstrologyColors.gold.withValues(alpha: 0.22)
          : AstrologyColors.raised,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AstrologyColors.gold
                  : AstrologyColors.line,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? AstrologyColors.gold : AstrologyColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
