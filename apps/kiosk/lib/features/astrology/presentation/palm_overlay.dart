import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/astrology/application/palm_path.dart';
import 'package:skp_kiosk/features/astrology/application/palm_roi.dart';

/// Dimmed camera mask with an open-palm cutout in the quality-checker ROI.
class PalmOverlayPainter extends CustomPainter {
  const PalmOverlayPainter();

  static const _gold = Color(0xFFE8C872);
  static const _teal = Color(0xFF2EC4A0);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromCenter(
      center: Offset(size.width * PalmRoi.centerX, size.height * PalmRoi.centerY),
      width: size.width * PalmRoi.width,
      height: size.height * PalmRoi.height,
    );
    final palm = openPalmPath(bounds);

    final dim = Path()
      ..addRect(Offset.zero & size)
      ..addPath(palm, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dim, Paint()..color = const Color(0xD60B1419));

    canvas.drawPath(
      palm,
      Paint()
        ..color = _gold.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.shortestSide * 0.034).clamp(12, 22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      palm,
      Paint()
        ..color = _gold.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      palm,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      palm,
      Paint()
        ..color = _teal.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.05
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final inset = Matrix4.identity()
      ..translateByDouble(bounds.center.dx, bounds.center.dy, 0, 1)
      ..scaleByDouble(0.965, 0.965, 1, 1)
      ..translateByDouble(-bounds.center.dx, -bounds.center.dy, 0, 1);
    canvas.drawPath(
      palm.transform(inset.storage),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
