import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/astrology/application/palm_path.dart';
import 'package:skp_kiosk/features/astrology/application/palm_roi.dart';

/// Dimmed camera mask with an open-palm cutout in the quality-checker ROI.
class PalmOverlayPainter extends CustomPainter {
  const PalmOverlayPainter();

  static const _gold = Color(0xFFE8C872);
  static const _teal = Color(0xFF0F6A5A);

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
    canvas.drawPath(dim, Paint()..color = const Color(0xD6101816));

    canvas.drawPath(
      palm,
      Paint()
        ..color = _gold.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.shortestSide * 0.028).clamp(10, 18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      palm,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      palm,
      Paint()
        ..color = _teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeJoin = StrokeJoin.round,
    );

    final inset = Matrix4.identity()
      ..translateByDouble(bounds.center.dx, bounds.center.dy, 0, 1)
      ..scaleByDouble(0.91, 0.91, 1, 1)
      ..translateByDouble(-bounds.center.dx, -bounds.center.dy, 0, 1);
    final inner = palm.transform(inset.storage);
    canvas.drawPath(
      dashedPath(inner, dash: 9, gap: 7),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Path dashedPath(Path source, {double dash = 8, double gap = 6}) {
  final dest = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var draw = true;
    while (distance < metric.length) {
      final length = draw ? dash : gap;
      final next = (distance + length).clamp(0.0, metric.length);
      if (draw) {
        dest.addPath(metric.extractPath(distance, next), Offset.zero);
      }
      distance = next;
      draw = !draw;
    }
  }
  return dest;
}
