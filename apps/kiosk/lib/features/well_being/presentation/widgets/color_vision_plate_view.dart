import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/well_being/domain/color_vision_plate.dart';

/// Ishihara-style dotted screening plate (original artwork, not clinical plates).
class ColorVisionPlateView extends StatelessWidget {
  const ColorVisionPlateView({
    super.key,
    required this.plate,
    this.size = 360,
  });

  final ColorVisionPlate plate;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Color vision screening plate',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PlateDotsPainter(plate: plate),
        ),
      ),
    );
  }
}

class _PlateDotsPainter extends CustomPainter {
  _PlateDotsPainter({required this.plate});

  final ColorVisionPlate plate;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final rng = math.Random(plate.id.hashCode ^ 17);

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFF8FAFC));

    final clip = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.save();
    canvas.clipPath(clip);

    final figurePath = _buildFigurePath(size, plate.figure);
    final step = size.shortestSide / 30;

    for (var y = center.dy - radius; y <= center.dy + radius; y += step) {
      for (var x = center.dx - radius; x <= center.dx + radius; x += step) {
        final point = Offset(
          x + (rng.nextDouble() - 0.5) * step * 0.4,
          y + (rng.nextDouble() - 0.5) * step * 0.4,
        );
        if ((point - center).distance > radius - 6) continue;

        final inFigure = figurePath != null && figurePath.contains(point);
        final palette = inFigure ? plate.figureColors : plate.groundColors;
        final color = palette[rng.nextInt(palette.length)];
        final r = step * (0.26 + rng.nextDouble() * 0.24);
        canvas.drawCircle(point, r, Paint()..color = color.withValues(alpha: 0.94));
      }
    }
    canvas.restore();

    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  Path? _buildFigurePath(Size size, String figure) {
    final text = figure.trim();
    if (text.isEmpty) return null;

    final path = Path();
    final digitW = size.shortestSide * (text.length >= 2 ? 0.28 : 0.36);
    final digitH = size.shortestSide * 0.52;
    final gap = size.shortestSide * 0.04;
    final totalW = digitW * text.length + gap * (text.length - 1);
    var left = (size.width - totalW) / 2;
    final top = (size.height - digitH) / 2;

    for (final ch in text.split('')) {
      final digit = int.tryParse(ch);
      if (digit != null) {
        path.addPath(
          _digitPath(digit, Rect.fromLTWH(left, top, digitW, digitH)),
          Offset.zero,
        );
      }
      left += digitW + gap;
    }
    return path;
  }

  /// Thick rounded stroke digits suitable for dotted-plate hit testing.
  Path _digitPath(int digit, Rect bounds) {
    final stroke = math.min(bounds.width, bounds.height) * 0.22;
    final inset = stroke * 0.55;
    final r = RRect.fromRectAndRadius(
      bounds.deflate(inset),
      Radius.circular(stroke * 0.35),
    );
    final path = Path();

    void addStroke(Path spine) {
      for (final metric in spine.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += stroke * 0.35) {
          final t = metric.getTangentForOffset(d);
          if (t == null) continue;
          path.addOval(Rect.fromCircle(center: t.position, radius: stroke * 0.55));
        }
      }
    }

    final left = r.left;
    final right = r.right;
    final top = r.top;
    final bottom = r.bottom;
    final midX = r.center.dx;
    final midY = r.center.dy;
    final w = r.width;
    final h = r.height;

    switch (digit) {
      case 0:
        path.addRRect(r);
        path.addRRect(r.deflate(stroke));
        break;
      case 1:
        addStroke(Path()
          ..moveTo(midX - w * 0.15, top + h * 0.18)
          ..lineTo(midX, top)
          ..lineTo(midX, bottom));
        addStroke(Path()
          ..moveTo(midX - w * 0.28, bottom)
          ..lineTo(midX + w * 0.28, bottom));
        break;
      case 2:
        addStroke(Path()
          ..moveTo(left, top + h * 0.22)
          ..quadraticBezierTo(left, top, midX, top)
          ..quadraticBezierTo(right, top, right, top + h * 0.22)
          ..quadraticBezierTo(right, midY, midX, midY)
          ..lineTo(left, bottom)
          ..lineTo(right, bottom));
        break;
      case 3:
        addStroke(Path()
          ..moveTo(left, top + h * 0.12)
          ..lineTo(right - w * 0.1, top)
          ..quadraticBezierTo(right, top, right, top + h * 0.22)
          ..quadraticBezierTo(right, midY, midX + w * 0.05, midY)
          ..quadraticBezierTo(right, midY, right, bottom - h * 0.22)
          ..quadraticBezierTo(right, bottom, midX, bottom)
          ..quadraticBezierTo(left, bottom, left, bottom - h * 0.12));
        break;
      case 4:
        addStroke(Path()
          ..moveTo(right - w * 0.2, top)
          ..lineTo(left, midY + h * 0.08)
          ..lineTo(right, midY + h * 0.08));
        addStroke(Path()
          ..moveTo(right - w * 0.15, top)
          ..lineTo(right - w * 0.15, bottom));
        break;
      case 5:
        addStroke(Path()
          ..moveTo(right, top)
          ..lineTo(left, top)
          ..lineTo(left, midY - h * 0.05)
          ..quadraticBezierTo(left, midY - h * 0.05, midX, midY - h * 0.08)
          ..quadraticBezierTo(right, midY - h * 0.08, right, midY + h * 0.12)
          ..quadraticBezierTo(right, bottom, midX, bottom)
          ..quadraticBezierTo(left, bottom, left, bottom - h * 0.12));
        break;
      case 6:
        addStroke(Path()
          ..moveTo(right - w * 0.1, top + h * 0.1)
          ..quadraticBezierTo(left, top, left, midY)
          ..quadraticBezierTo(left, bottom, midX, bottom)
          ..quadraticBezierTo(right, bottom, right, midY + h * 0.12)
          ..quadraticBezierTo(right, midY - h * 0.05, midX, midY - h * 0.05)
          ..quadraticBezierTo(left, midY - h * 0.05, left, midY + h * 0.05));
        break;
      case 7:
        addStroke(Path()
          ..moveTo(left, top)
          ..lineTo(right, top)
          ..lineTo(midX - w * 0.05, bottom));
        break;
      case 8:
        path.addOval(Rect.fromCenter(
          center: Offset(midX, top + h * 0.28),
          width: w * 0.9,
          height: h * 0.48,
        ));
        path.addOval(Rect.fromCenter(
          center: Offset(midX, bottom - h * 0.28),
          width: w * 0.95,
          height: h * 0.52,
        ));
        path.addOval(Rect.fromCenter(
          center: Offset(midX, top + h * 0.28),
          width: w * 0.9 - stroke * 1.6,
          height: h * 0.48 - stroke * 1.6,
        ));
        path.addOval(Rect.fromCenter(
          center: Offset(midX, bottom - h * 0.28),
          width: w * 0.95 - stroke * 1.6,
          height: h * 0.52 - stroke * 1.6,
        ));
        break;
      case 9:
        addStroke(Path()
          ..moveTo(left + w * 0.1, bottom - h * 0.1)
          ..quadraticBezierTo(right, bottom, right, midY)
          ..quadraticBezierTo(right, top, midX, top)
          ..quadraticBezierTo(left, top, left, midY - h * 0.12)
          ..quadraticBezierTo(left, midY + h * 0.05, midX, midY + h * 0.05)
          ..quadraticBezierTo(right, midY + h * 0.05, right, midY - h * 0.05));
        break;
      default:
        path.addRRect(r);
    }

    // Even-odd fill so ring digits (0/8) have hollow centers.
    return Path()..addPath(path, Offset.zero)..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldRepaint(covariant _PlateDotsPainter oldDelegate) {
    return oldDelegate.plate.id != plate.id;
  }
}
