import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_assets.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/glass_panel.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/palm_capture_viewport.dart';

/// Palm-specific analyzing screen shown during API submit.
class PalmAnalyzingView extends StatefulWidget {
  const PalmAnalyzingView({super.key});

  @override
  State<PalmAnalyzingView> createState() => _PalmAnalyzingViewState();
}

class _PalmAnalyzingViewState extends State<PalmAnalyzingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  static const _lines = [
    (label: 'Heart line', color: AstrologyColors.heartLine),
    (label: 'Head line', color: AstrologyColors.headLine),
    (label: 'Life line', color: AstrologyColors.lifeLine),
    (label: 'Fate line', color: AstrologyColors.fateLine),
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(AstrologyAssets.palmGuide), context);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 12),
      child: Column(
        children: [
          const PalmFlowStepRail(activeIndex: 1),
          const SizedBox(height: 12),
          Text(
            'Analyzing your palm',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AstrologyColors.palm,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tracing heart, head, life, and fate lines…',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AstrologyColors.muted,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      final pulse = 0.55 +
                          (0.5 - (_anim.value - 0.5).abs()) * 0.35;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AstrologyColors.palm
                                  .withValues(alpha: 0.18 + pulse * 0.2),
                              blurRadius: 28 + pulse * 12,
                            ),
                          ],
                        ),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: Opacity(
                              opacity: 0.72 + pulse * 0.2,
                              child: const AstrologyAssetImage(
                                asset: AstrologyAssets.palmGuide,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      for (var i = 0; i < _lines.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        Expanded(
                          child: _LineStatusCard(
                            label: _lines[i].label,
                            color: _lines[i].color,
                            progress: ((_anim.value * 4) - i).clamp(0.0, 1.0),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineStatusCard extends StatelessWidget {
  const _LineStatusCard({
    required this.label,
    required this.color,
    required this.progress,
  });

  final String label;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final done = progress >= 0.95;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderColor: color.withValues(alpha: 0.45),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AstrologyColors.raised,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            done ? 'Ready' : 'Analyzing…',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: done ? color : AstrologyColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
