import 'package:flutter/material.dart';

/// Soft circular dim so the hologram guide stays readable over the camera.
/// Quality math still uses openPalmPath / PalmRoi elsewhere — not this painter.
class PalmOverlayPainter extends CustomPainter {
  const PalmOverlayPainter({this.ready = false});

  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    final radius = size.shortestSide * 0.46;
    final hole = Path()..addOval(Rect.fromCircle(center: center, radius: radius));

    final dim = Path()
      ..addRect(Offset.zero & size)
      ..addPath(hole, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      dim,
      Paint()..color = Color(ready ? 0x281A2430 : 0x331A2430),
    );
  }

  @override
  bool shouldRepaint(covariant PalmOverlayPainter oldDelegate) =>
      oldDelegate.ready != ready;
}
