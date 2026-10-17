import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/ads/presentation/kiosk_wait_ads.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_assets.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/cosmic_backdrop.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/glass_panel.dart';

/// Casting wait: ads behind a glass “chart casting” overlay (keeps session hold).
class AstrologyCastingView extends StatefulWidget {
  const AstrologyCastingView({super.key, this.lines});

  /// Rotating status lines. Defaults to the palm-reading copy.
  final List<String>? lines;

  @override
  State<AstrologyCastingView> createState() => _AstrologyCastingViewState();
}

class _AstrologyCastingViewState extends State<AstrologyCastingView>
    with TickerProviderStateMixin {
  static const _defaultLines = [
    'Reading your palm lines…',
    'Mapping Lagna & Nakshatra…',
    'Weaving your period guidance…',
  ];

  List<String> get _lines =>
      (widget.lines == null || widget.lines!.isEmpty) ? _defaultLines : widget.lines!;

  late final AnimationController _orbit;
  late final AnimationController _copy;
  int _lineIndex = 0;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
    _copy = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _lineIndex = (_lineIndex + 1) % _lines.length);
          _copy.forward(from: 0);
        }
      });
    _copy.forward();
  }

  @override
  void dispose() {
    _orbit.dispose();
    _copy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CosmicBackdrop(),
        const Opacity(
          opacity: 0.42,
          child: KioskWaitAds(message: 'Preparing your reading…'),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: GlassPanel(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: AnimatedBuilder(
                      animation: _orbit,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _OrbitPainter(t: _orbit.value),
                          child: Center(
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AstrologyColors.gold.withValues(alpha: 0.55),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AstrologyColors.gold.withValues(alpha: 0.25),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: const ClipOval(
                                child: AstrologyAssetImage(
                                  asset: AstrologyAssets.sealMedallion,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'CASTING YOUR CHART',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AstrologyColors.gold,
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: _copy,
                    builder: (context, _) {
                      final t = Curves.easeInOut.transform(_copy.value);
                      final opacity = t < 0.15
                          ? t / 0.15
                          : t > 0.85
                              ? (1 - t) / 0.15
                              : 1.0;
                      return Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Text(
                          _lines[_lineIndex],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AstrologyColors.text,
                                height: 1.35,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.42;
    final ring = Paint()
      ..color = AstrologyColors.gold.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, ring);

    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 8; i++) {
      final angle = (t * math.pi * 2) + (i * math.pi * 2 / 8);
      final p = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      paint.color = AstrologyColors.gold.withValues(alpha: 0.35 + (i % 3) * 0.2);
      canvas.drawCircle(p, i.isEven ? 4.2 : 2.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => oldDelegate.t != t;
}
