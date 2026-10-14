import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_assets.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';

/// Deep navy wash + twinkling starfield for astrology surfaces.
class CosmicBackdrop extends StatefulWidget {
  const CosmicBackdrop({super.key, this.twinkle = true});

  final bool twinkle;

  @override
  State<CosmicBackdrop> createState() => _CosmicBackdropState();
}

class _CosmicBackdropState extends State<CosmicBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle;

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    if (widget.twinkle) {
      _twinkle.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant CosmicBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.twinkle && !_twinkle.isAnimating) {
      _twinkle.repeat(reverse: true);
    } else if (!widget.twinkle && _twinkle.isAnimating) {
      _twinkle.stop();
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AstrologyColors.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: AstrologyAssetImage(
              asset: AstrologyAssets.backdropNebula,
              fit: BoxFit.cover,
              opacity: 0.55,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.55),
                radius: 1.15,
                colors: [
                  AstrologyColors.gold.withValues(alpha: 0.14),
                  AstrologyColors.accent.withValues(alpha: 0.08),
                  AstrologyColors.canvas.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _twinkle,
            builder: (context, _) {
              return CustomPaint(
                painter: StarFieldPainter(twinkle: _twinkle.value),
                child: const SizedBox.expand(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class StarFieldPainter extends CustomPainter {
  const StarFieldPainter({this.twinkle = 0.5});

  final double twinkle;

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
      final phase = (i % 7) / 7.0;
      final pulse = 0.65 + 0.35 * math.sin((twinkle + phase) * math.pi * 2);
      final base = 0.08 + rnd.nextDouble() * 0.18;
      paint.color = (goldish ? AstrologyColors.gold : AstrologyColors.text)
          .withValues(alpha: (base * pulse).clamp(0.04, 0.42));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StarFieldPainter oldDelegate) =>
      oldDelegate.twinkle != twinkle;
}
