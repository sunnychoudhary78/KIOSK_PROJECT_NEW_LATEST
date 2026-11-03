import 'dart:ui';

/// Open right-hand silhouette (palm toward camera, thumb on the left) in [bounds].
///
/// Normalized coordinates fill [PalmRoi]-sized bounds with anatomical proportions:
/// middle longest, then index/ring, pinky shortest; soft tips and clear valleys.
Path openPalmPath(Rect bounds) {
  Offset p(double x, double y) =>
      Offset(bounds.left + x * bounds.width, bounds.top + y * bounds.height);

  final path = Path();

  void cubic(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    final a = p(x1, y1);
    final b = p(x2, y2);
    final d = p(x3, y3);
    path.cubicTo(a.dx, a.dy, b.dx, b.dy, d.dx, d.dy);
  }

  // Left wrist → thenar mound.
  path.moveTo(p(0.38, 0.985).dx, p(0.38, 0.985).dy);
  cubic(0.34, 0.92, 0.30, 0.82, 0.28, 0.70);

  // Thumb: angled out, rounded tip, returns to web.
  cubic(0.20, 0.66, 0.10, 0.58, 0.055, 0.50);
  cubic(0.02, 0.44, 0.02, 0.36, 0.07, 0.33);
  cubic(0.12, 0.30, 0.18, 0.32, 0.23, 0.38);
  cubic(0.27, 0.44, 0.295, 0.50, 0.31, 0.545);

  // Index finger.
  cubic(0.30, 0.42, 0.295, 0.22, 0.30, 0.10);
  cubic(0.305, 0.04, 0.335, 0.015, 0.365, 0.03);
  cubic(0.395, 0.045, 0.405, 0.12, 0.405, 0.22);
  cubic(0.405, 0.32, 0.41, 0.40, 0.43, 0.445);

  // Middle finger (longest).
  cubic(0.445, 0.30, 0.455, 0.12, 0.47, 0.04);
  cubic(0.485, 0.005, 0.525, 0.005, 0.545, 0.04);
  cubic(0.565, 0.08, 0.575, 0.18, 0.575, 0.30);
  cubic(0.575, 0.38, 0.58, 0.42, 0.60, 0.45);

  // Ring finger.
  cubic(0.615, 0.32, 0.63, 0.15, 0.65, 0.08);
  cubic(0.67, 0.035, 0.71, 0.03, 0.73, 0.07);
  cubic(0.75, 0.11, 0.755, 0.20, 0.75, 0.32);
  cubic(0.745, 0.40, 0.75, 0.445, 0.77, 0.47);

  // Pinky (shortest, slight outward lean).
  cubic(0.80, 0.40, 0.84, 0.30, 0.875, 0.24);
  cubic(0.90, 0.20, 0.935, 0.21, 0.94, 0.26);
  cubic(0.945, 0.31, 0.92, 0.38, 0.89, 0.46);
  cubic(0.86, 0.54, 0.84, 0.60, 0.82, 0.66);

  // Hypothenar → right wrist.
  cubic(0.79, 0.74, 0.74, 0.86, 0.68, 0.94);
  cubic(0.64, 0.98, 0.58, 0.995, 0.52, 0.995);
  cubic(0.46, 0.995, 0.41, 0.99, 0.38, 0.985);

  path.close();
  return path;
}
