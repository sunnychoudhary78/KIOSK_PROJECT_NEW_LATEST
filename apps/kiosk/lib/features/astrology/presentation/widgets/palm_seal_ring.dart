import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/astrology/application/palm_roi.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';

/// Gold seal ring that completes when palm quality is ready.
class PalmSealRing extends StatelessWidget {
  const PalmSealRing({super.key, required this.progress});

  /// 0..1 completion of the seal arc.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PalmSealRingPainter(progress: progress.clamp(0.0, 1.0)),
      child: const SizedBox.expand(),
    );
  }
}

class _PalmSealRingPainter extends CustomPainter {
  const _PalmSealRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    final center = Offset(
      size.width * PalmRoi.centerX,
      size.height * PalmRoi.centerY,
    );
    final radius = math.min(
          size.width * PalmRoi.width,
          size.height * PalmRoi.height,
        ) *
        0.62;

    final track = Paint()
      ..color = AstrologyColors.gold.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final sweep = progress * math.pi * 2;
    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweep,
        colors: [
          AstrologyColors.gold.withValues(alpha: 0.35),
          AstrologyColors.gold,
          AstrologyColors.goldSoft,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );

    if (progress >= 0.98) {
      final glow = Paint()
        ..color = AstrologyColors.gold.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(center, radius, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _PalmSealRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
