import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';

enum AstrologyReadingKind { kundali, palm, match, today }

extension AstrologyReadingKindStyle on AstrologyReadingKind {
  Color get accent => switch (this) {
    AstrologyReadingKind.kundali => const Color(0xFF7C3AED),
    AstrologyReadingKind.palm => const Color(0xFFEA580C),
    AstrologyReadingKind.match => const Color(0xFFE11D48),
    AstrologyReadingKind.today => const Color(0xFF0284C7),
  };

  Color get secondaryAccent => switch (this) {
    AstrologyReadingKind.kundali => const Color(0xFFC084FC),
    AstrologyReadingKind.palm => const Color(0xFFFBBF24),
    AstrologyReadingKind.match => const Color(0xFFF472B6),
    AstrologyReadingKind.today => const Color(0xFF38BDF8),
  };

  Color get bottomWaveColor => switch (this) {
    AstrologyReadingKind.kundali => const Color(0xFFEDE9FE),
    AstrologyReadingKind.palm => const Color(0xFFFFEDD5),
    AstrologyReadingKind.match => const Color(0xFFFCE7F3),
    AstrologyReadingKind.today => const Color(0xFFE0F2FE),
  };
}

/// Rich, high-fidelity drawn mark for a reading matching the signature 3D aesthetic.
class ReadingEmblem extends StatelessWidget {
  const ReadingEmblem({
    super.key,
    required this.kind,
    this.size = 84,
    this.color,
  });

  final AstrologyReadingKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _Astrology3DEmblemPainter(kind: kind),
      ),
    );
  }
}

class _Astrology3DEmblemPainter extends CustomPainter {
  const _Astrology3DEmblemPainter({required this.kind});

  final AstrologyReadingKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.46;

    switch (kind) {
      case AstrologyReadingKind.kundali:
        _paintKundali(canvas, center, radius);
      case AstrologyReadingKind.palm:
        _paintPalm(canvas, center, radius);
      case AstrologyReadingKind.match:
        _paintMatch(canvas, center, radius);
      case AstrologyReadingKind.today:
        _paintToday(canvas, center, radius);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. MY KUNDALI: Illuminated Zodiac Wheel + Glowing 3D Lotus
  // ─────────────────────────────────────────────────────────────────────────
  void _paintKundali(Canvas canvas, Offset center, double radius) {
    // A. Neon pedestal base ring
    final baseCenter = Offset(center.dx, center.dy + radius * 0.72);
    final baseRect = Rect.fromCenter(
      center: baseCenter,
      width: radius * 1.65,
      height: radius * 0.38,
    );
    final baseGlowPaint = Paint()
      ..color = const Color(0xFF818CF8).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(baseRect, baseGlowPaint);

    final baseStrokePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF818CF8), Color(0xFFE879F9), Color(0xFF38BDF8)],
      ).createShader(baseRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(baseRect, baseStrokePaint);

    // B. Zodiac circular medallion
    final discCenter = Offset(center.dx, center.dy - radius * 0.05);
    final discRadius = radius * 0.76;

    // Disc glow
    canvas.drawCircle(
      discCenter,
      discRadius + 4,
      Paint()
        ..color = const Color(0xFF9333EA).withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Disc body
    final discRect = Rect.fromCircle(center: discCenter, radius: discRadius);
    final discPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF3B0764), Color(0xFF1E1B4B), Color(0xFF0F172A)],
        stops: [0.3, 0.75, 1.0],
      ).createShader(discRect);
    canvas.drawCircle(discCenter, discRadius, discPaint);

    // Outer gold ring
    final outerRingPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFDE68A), Color(0xFFD97706), Color(0xFFFDE68A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(discRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(discCenter, discRadius, outerRingPaint);

    // Inner concentric ring
    final innerRingPaint = Paint()
      ..color = const Color(0xFFFDE68A).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(discCenter, discRadius * 0.72, innerRingPaint);

    // 12 Zodiac spokes & dots
    final dotPaint = Paint()..color = const Color(0xFFFDE68A);
    final spokePaint = Paint()
      ..color = const Color(0xFFC084FC).withValues(alpha: 0.35)
      ..strokeWidth = 0.8;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final p1 = Offset(
        discCenter.dx + discRadius * 0.72 * math.cos(angle),
        discCenter.dy + discRadius * 0.72 * math.sin(angle),
      );
      final p2 = Offset(
        discCenter.dx + discRadius * 0.95 * math.cos(angle),
        discCenter.dy + discRadius * 0.95 * math.sin(angle),
      );
      canvas.drawLine(p1, p2, spokePaint);

      final midAngle = ((i * 30) + 15) * math.pi / 180;
      final dotPos = Offset(
        discCenter.dx + discRadius * 0.85 * math.cos(midAngle),
        discCenter.dy + discRadius * 0.85 * math.sin(midAngle),
      );
      canvas.drawCircle(dotPos, 1.2, dotPaint);
    }

    // C. Glowing multi-petal lotus in the center
    final lotusCenter = discCenter;
    final petalCount = 8;
    final petalLen = discRadius * 0.44;
    final petalWidth = discRadius * 0.22;

    for (int i = 0; i < petalCount; i++) {
      final angle = (i * (360 / petalCount)) * math.pi / 180;
      canvas.save();
      canvas.translate(lotusCenter.dx, lotusCenter.dy);
      canvas.rotate(angle);

      final petalPath = Path()
        ..moveTo(0, 0)
        ..cubicTo(
          -petalWidth,
          -petalLen * 0.5,
          -petalWidth * 0.6,
          -petalLen,
          0,
          -petalLen,
        )
        ..cubicTo(
          petalWidth * 0.6,
          -petalLen,
          petalWidth,
          -petalLen * 0.5,
          0,
          0,
        );

      final petalShader = const LinearGradient(
        colors: [Color(0xFFE879F9), Color(0xFFEC4899), Color(0xFFBE185D)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(-petalWidth, -petalLen, petalWidth * 2, petalLen));

      canvas.drawPath(petalPath, Paint()..shader = petalShader);

      canvas.drawLine(
        Offset.zero,
        Offset(0, -petalLen * 0.85),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.65)
          ..strokeWidth = 0.9,
      );

      canvas.restore();
    }

    final innerPetalLen = discRadius * 0.30;
    final innerPetalWidth = discRadius * 0.16;
    for (int i = 0; i < petalCount; i++) {
      final angle = ((i * (360 / petalCount)) + 22.5) * math.pi / 180;
      canvas.save();
      canvas.translate(lotusCenter.dx, lotusCenter.dy);
      canvas.rotate(angle);

      final innerPath = Path()
        ..moveTo(0, 0)
        ..cubicTo(
          -innerPetalWidth,
          -innerPetalLen * 0.5,
          -innerPetalWidth * 0.5,
          -innerPetalLen,
          0,
          -innerPetalLen,
        )
        ..cubicTo(
          innerPetalWidth * 0.5,
          -innerPetalLen,
          innerPetalWidth,
          -innerPetalLen * 0.5,
          0,
          0,
        );

      final innerShader = const LinearGradient(
        colors: [Color(0xFFFDE047), Color(0xFFF472B6), Color(0xFFDB2777)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(-innerPetalWidth, -innerPetalLen, innerPetalWidth * 2, innerPetalLen));

      canvas.drawPath(innerPath, Paint()..shader = innerShader);
      canvas.restore();
    }

    canvas.drawCircle(
      lotusCenter,
      discRadius * 0.14,
      Paint()
        ..color = const Color(0xFFFDE047)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      lotusCenter,
      discRadius * 0.10,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0xFFFBBF24), Color(0xFFD97706)],
        ).createShader(Rect.fromCircle(center: lotusCenter, radius: discRadius * 0.10)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. PALM INSIGHTS: Golden Metallic Hand + Scan Brackets + Biometric Lines
  // ─────────────────────────────────────────────────────────────────────────
  void _paintPalm(Canvas canvas, Offset center, double radius) {
    final baseCenter = Offset(center.dx, center.dy + radius * 0.74);
    final baseRect = Rect.fromCenter(
      center: baseCenter,
      width: radius * 1.6,
      height: radius * 0.36,
    );
    final baseGlowPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(baseRect, baseGlowPaint);

    final baseStrokePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFEA580C)],
      ).createShader(baseRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(baseRect, baseStrokePaint);

    final scanRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - radius * 0.05),
      width: radius * 1.65,
      height: radius * 1.65,
    );
    final bracketPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final armLen = radius * 0.28;
    final tl = Path()
      ..moveTo(scanRect.left, scanRect.top + armLen)
      ..lineTo(scanRect.left, scanRect.top + 4)
      ..arcToPoint(Offset(scanRect.left + 4, scanRect.top), radius: const Radius.circular(4))
      ..lineTo(scanRect.left + armLen, scanRect.top);
    canvas.drawPath(tl, bracketPaint);

    final tr = Path()
      ..moveTo(scanRect.right - armLen, scanRect.top)
      ..lineTo(scanRect.right - 4, scanRect.top)
      ..arcToPoint(Offset(scanRect.right, scanRect.top + 4), radius: const Radius.circular(4))
      ..lineTo(scanRect.right, scanRect.top + armLen);
    canvas.drawPath(tr, bracketPaint);

    final bl = Path()
      ..moveTo(scanRect.left, scanRect.bottom - armLen)
      ..lineTo(scanRect.left, scanRect.bottom - 4)
      ..arcToPoint(Offset(scanRect.left + 4, scanRect.bottom), radius: const Radius.circular(4))
      ..lineTo(scanRect.left + armLen, scanRect.bottom);
    canvas.drawPath(bl, bracketPaint);

    final br = Path()
      ..moveTo(scanRect.right - armLen, scanRect.bottom)
      ..lineTo(scanRect.right - 4, scanRect.bottom)
      ..arcToPoint(Offset(scanRect.right, scanRect.bottom - 4), radius: const Radius.circular(4))
      ..lineTo(scanRect.right, scanRect.bottom - armLen);
    canvas.drawPath(br, bracketPaint);

    final handCenter = Offset(center.dx, center.dy - radius * 0.04);
    final handWidth = radius * 0.95;
    final handHeight = radius * 1.15;
    final handRect = Rect.fromCenter(center: handCenter, width: handWidth, height: handHeight);

    canvas.drawOval(
      handRect,
      Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final palmPath = Path();
    final pw = handWidth * 0.5;
    final ph = handHeight * 0.5;

    palmPath.moveTo(handCenter.dx - pw * 0.5, handCenter.dy + ph * 0.85);
    palmPath.cubicTo(
      handCenter.dx - pw * 1.1,
      handCenter.dy + ph * 0.45,
      handCenter.dx - pw * 1.15,
      handCenter.dy - ph * 0.05,
      handCenter.dx - pw * 0.8,
      handCenter.dy - ph * 0.15,
    );
    palmPath.cubicTo(
      handCenter.dx - pw * 0.55,
      handCenter.dy - ph * 0.2,
      handCenter.dx - pw * 0.45,
      handCenter.dy + ph * 0.1,
      handCenter.dx - pw * 0.4,
      handCenter.dy - ph * 0.35,
    );
    palmPath.cubicTo(
      handCenter.dx - pw * 0.4,
      handCenter.dy - ph * 0.85,
      handCenter.dx - pw * 0.2,
      handCenter.dy - ph * 0.85,
      handCenter.dx - pw * 0.2,
      handCenter.dy - ph * 0.35,
    );
    palmPath.cubicTo(
      handCenter.dx - pw * 0.2,
      handCenter.dy - ph * 0.95,
      handCenter.dx + pw * 0.05,
      handCenter.dy - ph * 0.95,
      handCenter.dx + pw * 0.05,
      handCenter.dy - ph * 0.35,
    );
    palmPath.cubicTo(
      handCenter.dx + pw * 0.05,
      handCenter.dy - ph * 0.85,
      handCenter.dx + pw * 0.3,
      handCenter.dy - ph * 0.85,
      handCenter.dx + pw * 0.3,
      handCenter.dy - ph * 0.35,
    );
    palmPath.cubicTo(
      handCenter.dx + pw * 0.3,
      handCenter.dy - ph * 0.65,
      handCenter.dx + pw * 0.55,
      handCenter.dy - ph * 0.65,
      handCenter.dx + pw * 0.55,
      handCenter.dy - ph * 0.15,
    );
    palmPath.cubicTo(
      handCenter.dx + pw * 0.75,
      handCenter.dy + ph * 0.2,
      handCenter.dx + pw * 0.7,
      handCenter.dy + ph * 0.65,
      handCenter.dx + pw * 0.45,
      handCenter.dy + ph * 0.85,
    );
    palmPath.close();

    final handShader = const LinearGradient(
      colors: [Color(0xFFFEF3C7), Color(0xFFFBBF24), Color(0xFFD97706), Color(0xFF92400E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(handRect);

    canvas.drawPath(palmPath, Paint()..shader = handShader);
    canvas.drawPath(
      palmPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final linePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final lineGlowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final heartPath = Path()
      ..moveTo(handCenter.dx + pw * 0.45, handCenter.dy - ph * 0.05)
      ..quadraticBezierTo(
        handCenter.dx,
        handCenter.dy - ph * 0.15,
        handCenter.dx - pw * 0.25,
        handCenter.dy - ph * 0.25,
      );
    canvas.drawPath(heartPath, lineGlowPaint);
    canvas.drawPath(heartPath, linePaint);

    final headPath = Path()
      ..moveTo(handCenter.dx - pw * 0.35, handCenter.dy - ph * 0.05)
      ..quadraticBezierTo(
        handCenter.dx,
        handCenter.dy + ph * 0.08,
        handCenter.dx + pw * 0.38,
        handCenter.dy + ph * 0.15,
      );
    canvas.drawPath(headPath, lineGlowPaint);
    canvas.drawPath(headPath, linePaint);

    final lifePath = Path()
      ..moveTo(handCenter.dx - pw * 0.35, handCenter.dy - ph * 0.05)
      ..quadraticBezierTo(
        handCenter.dx - pw * 0.15,
        handCenter.dy + ph * 0.35,
        handCenter.dx - pw * 0.1,
        handCenter.dy + ph * 0.65,
      );
    canvas.drawPath(lifePath, lineGlowPaint);
    canvas.drawPath(lifePath, linePaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(handCenter.dx - pw * 0.35, handCenter.dy - ph * 0.05), 2.2, dotPaint);
    canvas.drawCircle(Offset(handCenter.dx, handCenter.dy + ph * 0.08), 2.0, dotPaint);
    canvas.drawCircle(Offset(handCenter.dx - pw * 0.25, handCenter.dy - ph * 0.25), 2.0, dotPaint);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. MATCH KUNDALIS: Intertwined 3D Metallic Ribbon Hearts + Glow
  // ─────────────────────────────────────────────────────────────────────────
  void _paintMatch(Canvas canvas, Offset center, double radius) {
    final baseCenter = Offset(center.dx, center.dy + radius * 0.74);
    final baseRect = Rect.fromCenter(
      center: baseCenter,
      width: radius * 1.6,
      height: radius * 0.36,
    );
    final baseGlowPaint = Paint()
      ..color = const Color(0xFFF43F5E).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(baseRect, baseGlowPaint);

    final baseStrokePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFFF43F5E), Color(0xFFD946EF)],
      ).createShader(baseRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(baseRect, baseStrokePaint);

    final heartSize = radius * 0.76;
    final leftCenter = Offset(center.dx - radius * 0.24, center.dy + radius * 0.05);
    final rightCenter = Offset(center.dx + radius * 0.24, center.dy + radius * 0.05);

    Path createHeart(double s) {
      final p = Path();
      p.moveTo(0, s * 0.32);
      p.cubicTo(-s * 0.72, -s * 0.15, -s * 0.72, -s * 0.65, 0, -s * 0.45);
      p.cubicTo(s * 0.72, -s * 0.65, s * 0.72, -s * 0.15, 0, s * 0.32);
      p.close();
      return p;
    }

    // Left Heart
    canvas.save();
    canvas.translate(leftCenter.dx, leftCenter.dy);
    canvas.rotate(-math.pi / 16);

    final leftHeartPath = createHeart(heartSize);
    final leftShader = const LinearGradient(
      colors: [Color(0xFF7DD3FC), Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF1E40AF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: heartSize));

    canvas.drawPath(
      leftHeartPath,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawPath(
      leftHeartPath,
      Paint()
        ..shader = leftShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = heartSize * 0.28
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawPath(
      leftHeartPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = heartSize * 0.06
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    // Right Heart
    canvas.save();
    canvas.translate(rightCenter.dx, rightCenter.dy);
    canvas.rotate(math.pi / 16);

    final rightHeartPath = createHeart(heartSize);
    final rightShader = const LinearGradient(
      colors: [Color(0xFFFDA4AF), Color(0xFFFB7185), Color(0xFFE11D48), Color(0xFF881337)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: heartSize));

    canvas.drawPath(
      rightHeartPath,
      Paint()
        ..color = const Color(0xFFFB7185).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawPath(
      rightHeartPath,
      Paint()
        ..shader = rightShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = heartSize * 0.28
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawPath(
      rightHeartPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = heartSize * 0.06
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    // Floating Mini Heart
    final miniCenter = Offset(center.dx, center.dy - radius * 0.42);
    final miniSize = radius * 0.32;
    canvas.save();
    canvas.translate(miniCenter.dx, miniCenter.dy);

    final miniPath = createHeart(miniSize);
    final miniShader = const RadialGradient(
      colors: [Colors.white, Color(0xFFF43F5E), Color(0xFFBE185D)],
      stops: [0.0, 0.4, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: miniSize));

    canvas.drawPath(
      miniPath,
      Paint()
        ..color = const Color(0xFFF43F5E).withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(miniPath, Paint()..shader = miniShader);
    canvas.restore();

    _drawSparkle(canvas, Offset(center.dx - radius * 0.62, center.dy - radius * 0.28), 5.0, const Color(0xFF38BDF8));
    _drawSparkle(canvas, Offset(center.dx + radius * 0.62, center.dy - radius * 0.28), 5.0, const Color(0xFFFB7185));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. TODAY & PERIODS: 3D Calendar + Golden Crescent Moon & Star
  // ─────────────────────────────────────────────────────────────────────────
  void _paintToday(Canvas canvas, Offset center, double radius) {
    final baseCenter = Offset(center.dx, center.dy + radius * 0.74);
    final baseRect = Rect.fromCenter(
      center: baseCenter,
      width: radius * 1.6,
      height: radius * 0.36,
    );
    final baseGlowPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(baseRect, baseGlowPaint);

    final baseStrokePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF0284C7), Color(0xFF1D4ED8)],
      ).createShader(baseRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(baseRect, baseStrokePaint);

    final calCenter = Offset(center.dx, center.dy - radius * 0.02);
    final calW = radius * 1.35;
    final calH = radius * 1.25;

    final rearRect = Rect.fromCenter(
      center: Offset(calCenter.dx - 4, calCenter.dy - 6),
      width: calW,
      height: calH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rearRect, const Radius.circular(14)),
      Paint()..color = const Color(0xFFE2E8F0),
    );

    final frontRect = Rect.fromCenter(
      center: calCenter,
      width: calW,
      height: calH,
    );
    final frontRRect = RRect.fromRectAndRadius(frontRect, const Radius.circular(14));

    canvas.drawRRect(
      frontRRect,
      Paint()
        ..color = const Color(0xFF0284C7).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final calShader = const LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(frontRect);
    canvas.drawRRect(frontRRect, Paint()..shader = calShader);

    canvas.drawRRect(
      frontRRect,
      Paint()
        ..color = const Color(0xFF93C5FD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final headerPath = Path()
      ..moveTo(frontRect.left, frontRect.top + 14)
      ..arcToPoint(Offset(frontRect.left + 14, frontRect.top), radius: const Radius.circular(14))
      ..lineTo(frontRect.right - 14, frontRect.top)
      ..arcToPoint(Offset(frontRect.right, frontRect.top + 14), radius: const Radius.circular(14))
      ..lineTo(frontRect.right, frontRect.top + calH * 0.38)
      ..lineTo(frontRect.left, frontRect.top + calH * 0.38)
      ..close();

    final headerShader = const LinearGradient(
      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(frontRect);
    canvas.drawPath(headerPath, Paint()..shader = headerShader);

    final ringCount = 4;
    final ringSpan = calW * 0.65;
    final ringStartX = calCenter.dx - ringSpan / 2;

    for (int i = 0; i < ringCount; i++) {
      final rx = ringStartX + (ringSpan / (ringCount - 1)) * i;
      final ry = frontRect.top - 2;

      final loopRect = Rect.fromCenter(center: Offset(rx, ry), width: 6.0, height: 16.0);
      final loopPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFB45309)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(loopRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawRRect(RRect.fromRectAndRadius(loopRect, const Radius.circular(3)), loopPaint);
    }

    final moonCenter = Offset(calCenter.dx - 8, frontRect.top + calH * 0.20);
    final moonRadius = calH * 0.14;

    canvas.drawCircle(
      moonCenter,
      moonRadius + 3,
      Paint()
        ..color = const Color(0xFFFBBF24).withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final moonBounds = Rect.fromCircle(center: moonCenter, radius: moonRadius);
    canvas.saveLayer(moonBounds.inflate(4), Paint());

    final moonShader = const LinearGradient(
      colors: [Color(0xFFFFFBEB), Color(0xFFFDE047), Color(0xFFF59E0B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(moonBounds);

    canvas.drawCircle(moonCenter, moonRadius, Paint()..shader = moonShader);
    canvas.drawCircle(
      Offset(moonCenter.dx + moonRadius * 0.52, moonCenter.dy - moonRadius * 0.15),
      moonRadius * 0.82,
      Paint()..blendMode = BlendMode.dstOut,
    );
    canvas.restore();

    _drawSparkle(
      canvas,
      Offset(moonCenter.dx + moonRadius * 0.85, moonCenter.dy - moonRadius * 0.10),
      6.0,
      const Color(0xFFFDE047),
    );

    final dotPaint = Paint()..color = const Color(0xFF93C5FD);
    final startY = frontRect.top + calH * 0.52;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 5; c++) {
        final cx = calCenter.dx - calW * 0.32 + c * (calW * 0.16);
        final cy = startY + r * (calH * 0.14);
        canvas.drawCircle(Offset(cx, cy), 2.2, dotPaint);
      }
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
    final p = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy);

    canvas.drawPath(
      p,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(p, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _Astrology3DEmblemPainter oldDelegate) {
    return oldDelegate.kind != kind;
  }
}

/// Organic wave painter at bottom-right corner.
class _CardBottomWavePainter extends CustomPainter {
  const _CardBottomWavePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width * 0.36, size.height);
    path.cubicTo(
      size.width * 0.55,
      size.height * 0.98,
      size.width * 0.65,
      size.height * 0.58,
      size.width,
      size.height * 0.52,
    );
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CardBottomWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Hub tile: matching the reference design exactly with soft pearlescent gradient wash,
/// glowing asset image, bold modern typography, and a circular arrow button.
class AstrologyReadingCard extends StatefulWidget {
  const AstrologyReadingCard({
    super.key,
    required this.kind,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final AstrologyReadingKind kind;
  final String image;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<AstrologyReadingCard> createState() => _AstrologyReadingCardState();
}

class _AstrologyReadingCardState extends State<AstrologyReadingCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.kind.accent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // In dark mode: wave is a soft 16% alpha of the accent so it never blinds or distorts.
    // In light mode: uses the pastel bottomWaveColor.
    final waveColor = isDark
        ? widget.kind.accent.withValues(alpha: 0.16)
        : widget.kind.bottomWaveColor;

    final (cardGradient, borderColor, shadowColor) = switch (widget.kind) {
      AstrologyReadingKind.kundali => (
        isDark
            ? const LinearGradient(
                colors: [Color(0xFF1E1738), Color(0xFF2A1C50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
                stops: [0.35, 0.75, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        isDark ? const Color(0xFF6B21A8) : const Color(0xFFDDD6FE),
        const Color(0xFF7C3AED),
      ),
      AstrologyReadingKind.palm => (
        isDark
            ? const LinearGradient(
                colors: [Color(0xFF231815), Color(0xFF382315)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFFFBEB), Color(0xFFFFEDD5)],
                stops: [0.35, 0.75, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        isDark ? const Color(0xFF9A3412) : const Color(0xFFFED7AA),
        const Color(0xFFEA580C),
      ),
      AstrologyReadingKind.match => (
        isDark
            ? const LinearGradient(
                colors: [Color(0xFF241523), Color(0xFF3B1832)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFDF2F8), Color(0xFFFCE7F3)],
                stops: [0.35, 0.75, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        isDark ? const Color(0xFF9F1239) : const Color(0xFFFBCFE8),
        const Color(0xFFE11D48),
      ),
      AstrologyReadingKind.today => (
        isDark
            ? const LinearGradient(
                colors: [Color(0xFF131D33), Color(0xFF172554)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
                stops: [0.35, 0.75, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD),
        const Color(0xFF0284C7),
      ),
    };

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 140),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: cardGradient,
          border: Border.all(
            color: borderColor.withValues(alpha: isDark ? 0.7 : 0.85),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            if (!isDark)
              const BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Bottom Organic Wave (controlled opacity in dark mode)
              CustomPaint(
                painter: _CardBottomWavePainter(color: waveColor),
                size: Size.infinite,
              ),

              // Content
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapUp: (_) => setState(() => _pressed = false),
                  onTapCancel: () => setState(() => _pressed = false),
                  borderRadius: BorderRadius.circular(24),
                  splashColor: accent.withValues(alpha: 0.12),
                  highlightColor: accent.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    child: Row(
                      children: [
                        // 1. Asset PNG image
                        SizedBox(
                          width: 92,
                          height: 92,
                          child: Image.asset(
                            widget.image,
                            width: 92,
                            height: 92,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stack) => Icon(
                              Icons.auto_awesome,
                              size: 56,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // 2. Title & Subtitle
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                widget.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 14),

                        // 3. Circular Arrow Button
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            border: Border.all(
                              color: accent.withValues(alpha: isDark ? 0.8 : 0.85),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.20),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: accent,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
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
