import 'dart:ui';

/// Open right-hand silhouette (palm toward camera, thumb on the left) in [bounds].
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

  // Left wrist → thenar.
  final start = p(0.37, 0.99);
  path.moveTo(start.dx, start.dy);
  c(0.33, 0.90, 0.29, 0.78, 0.27, 0.66);

  // Thumb: thick, shorter, angled out from the thenar.
  c(0.16, 0.62, 0.07, 0.54, 0.04, 0.46);
  c(0.01, 0.40, 0.03, 0.33, 0.11, 0.32);
  c(0.18, 0.32, 0.25, 0.40, 0.29, 0.50);

  // Index.
  c(0.29, 0.36, 0.29, 0.18, 0.30, 0.09);
  c(0.31, 0.03, 0.36, 0.015, 0.39, 0.04);
  c(0.42, 0.07, 0.42, 0.20, 0.42, 0.37);
  c(0.42, 0.40, 0.43, 0.42, 0.46, 0.42);

  // Middle (longest).
  c(0.47, 0.20, 0.48, 0.07, 0.50, 0.025);
  c(0.52, 0.00, 0.56, 0.00, 0.58, 0.03);
  c(0.60, 0.07, 0.61, 0.20, 0.61, 0.38);
  c(0.61, 0.41, 0.63, 0.43, 0.66, 0.43);

  // Ring.
  c(0.67, 0.22, 0.68, 0.09, 0.70, 0.05);
  c(0.72, 0.02, 0.76, 0.025, 0.78, 0.06);
  c(0.80, 0.11, 0.80, 0.24, 0.79, 0.40);
  c(0.79, 0.43, 0.80, 0.45, 0.83, 0.45);

  // Pinky: shortest, angled outward.
  c(0.86, 0.36, 0.90, 0.26, 0.92, 0.20);
  c(0.94, 0.16, 0.96, 0.18, 0.95, 0.23);
  c(0.93, 0.30, 0.90, 0.40, 0.86, 0.50);

  // Hypothenar → right wrist.
  c(0.82, 0.62, 0.78, 0.78, 0.72, 0.90);
  c(0.69, 0.95, 0.66, 0.99, 0.62, 0.99);

  path.close();
  return path;
}
