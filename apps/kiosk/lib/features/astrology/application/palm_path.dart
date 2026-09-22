import 'dart:ui';

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
