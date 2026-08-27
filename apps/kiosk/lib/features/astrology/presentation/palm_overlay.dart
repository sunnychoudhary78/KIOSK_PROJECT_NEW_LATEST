import 'package:flutter/material.dart';

/// Dimmed camera mask with an open-palm cutout in the quality-checker ROI.
class PalmOverlayPainter extends CustomPainter {
  const PalmOverlayPainter();

  static const _gold = Color(0xFFE8C872);
  static const _teal = Color(0xFF0F6A5A);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.52),
      width: size.width * 0.50,
      height: size.height * 0.64,
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

/// Open right-hand silhouette (thumb on the left) in [bounds].
Path openPalmPath(Rect bounds) {
  Offset p(double x, double y) =>
      Offset(bounds.left + x * bounds.width, bounds.top + y * bounds.height);

  final path = Path();
  void c(double x1, double y1, double x2, double y2, double x3, double y3) {
    final a = p(x1, y1);
    final b = p(x2, y2);
    final d = p(x3, y3);
    path.cubicTo(a.dx, a.dy, b.dx, b.dy, d.dx, d.dy);
  }

  final start = p(0.38, 0.98);
  path.moveTo(start.dx, start.dy);
  c(0.34, 0.84, 0.32, 0.68, 0.31, 0.58);
  c(0.20, 0.56, 0.09, 0.52, 0.05, 0.45);
  c(0.01, 0.38, 0.05, 0.30, 0.14, 0.31);
  c(0.22, 0.32, 0.27, 0.40, 0.31, 0.48);
  c(0.29, 0.34, 0.25, 0.16, 0.27, 0.09);
  c(0.28, 0.02, 0.37, 0.01, 0.39, 0.10);
  c(0.41, 0.18, 0.41, 0.32, 0.42, 0.38);
  c(0.41, 0.24, 0.40, 0.08, 0.43, 0.03);
  c(0.46, -0.02, 0.53, -0.01, 0.54, 0.07);
  c(0.55, 0.16, 0.54, 0.30, 0.54, 0.36);
  c(0.54, 0.20, 0.54, 0.04, 0.57, 0.00);
  c(0.60, -0.04, 0.67, -0.03, 0.68, 0.05);
  c(0.70, 0.14, 0.68, 0.28, 0.67, 0.36);
  c(0.68, 0.24, 0.69, 0.10, 0.73, 0.05);
  c(0.77, 0.00, 0.84, 0.03, 0.84, 0.12);
  c(0.84, 0.22, 0.80, 0.36, 0.76, 0.44);
  c(0.82, 0.52, 0.80, 0.64, 0.73, 0.74);
  c(0.68, 0.84, 0.64, 0.94, 0.62, 0.98);
  path.close();
  return path;
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
