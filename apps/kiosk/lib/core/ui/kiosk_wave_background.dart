import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';

/// Renders the signature Athena multi-layered wave background with
/// clean white-gray canvas, rich and clearly visible fluid wave fills,
/// and subtle corner dot-matrix patterns.
class KioskWaveBackground extends StatelessWidget {
  const KioskWaveBackground({
    super.key,
    required this.child,
    this.showDots = true,
  });

  final Widget child;
  final bool showDots;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Clean white-gray luminous canvas gradient
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF050925) : const Color(0xFFFFFFFF),
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.50, 1.0],
                    colors: [
                      Color(0xFF050925),
                      Color(0xFF171038),
                      Color(0xFF090821),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.40, 0.75, 1.0],
                    colors: [
                      Color(0xFFFFFFFF), // Pure white top
                      Color(0xFFF8FAFC), // Ultra soft clean light-gray
                      Color(0xFFF1F5F9), // Elegant subtle gray
                      Color(0xFFF8FAFC),
                    ],
                  ),
          ),
        ),

        // 2. Ambient top dome glow — ONLY in dark mode
        if (isDark)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -1.0),
                radius: 1.1,
                stops: [0.0, 0.55],
                colors: [
                  Color(0xFF32104F),
                  Colors.transparent,
                ],
              ),
            ),
          ),

        // 3. Flowing clearly visible colored waves & corner dot matrices
        RepaintBoundary(
          child: CustomPaint(
            painter: _WaveBackgroundPainter(
              colors: colors,
              isDark: isDark,
              showDots: showDots,
            ),
            size: Size.infinite,
          ),
        ),

        // Child content on top
        child,
      ],
    );
  }
}

class _WaveBackgroundPainter extends CustomPainter {
  const _WaveBackgroundPainter({
    required this.colors,
    required this.isDark,
    required this.showDots,
  });

  final AthenaColors colors;
  final bool isDark;
  final bool showDots;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Corner dot-matrix halftone patterns
    if (showDots) {
      _drawDotMatrix(canvas, w, h);
    }

    // 2. Top Wave Ribbons (two clearly visible fluid waves)
    _drawTopWave(canvas, w, h);

    // 3. Bottom Multi-layered Colored Waves (clearly visible pastel gradient layers)
    _drawBottomWave(canvas, w, h);
  }

  void _drawDotMatrix(Canvas canvas, double w, double h) {
    final dotColor = isDark
        ? const Color(0x3500E5FF)
        : const Color(0x9560A5FA); // Crisp, distinct sky-blue halftone dots
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const spacing = 18.0;
    const dotRadius = 1.8;

    // Top-left dot grid (9 columns x 8 rows)
    for (int col = 0; col < 9; col++) {
      for (int row = 0; row < 8; row++) {
        final opacityFactor = (1.0 - (col / 9)) * (1.0 - (row / 8));
        if (opacityFactor > 0.04) {
          final x = 16.0 + col * spacing;
          final y = 14.0 + row * spacing;
          canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
        }
      }
    }

    // Top-right dot grid (9 columns x 8 rows)
    for (int col = 0; col < 9; col++) {
      for (int row = 0; row < 8; row++) {
        final opacityFactor = (col / 9) * (1.0 - (row / 8));
        if (opacityFactor > 0.04) {
          final x = w - 16.0 - (8 - col) * spacing;
          final y = 14.0 + row * spacing;
          canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
        }
      }
    }
  }

  void _drawTopWave(Canvas canvas, double w, double h) {
    if (isDark) {
      final path = Path();
      path.moveTo(0, 0);
      path.lineTo(w, 0);
      path.lineTo(w, h * 0.16);

      path.cubicTo(
        w * 0.68, h * 0.23,
        w * 0.36, h * 0.11,
        0, h * 0.18,
      );
      path.close();

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0x3500E5FF),
            Color(0x287928CA),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.28));

      canvas.drawPath(path, paint);

      final edgePath = Path();
      edgePath.moveTo(w, h * 0.16);
      edgePath.cubicTo(
        w * 0.68, h * 0.23,
        w * 0.36, h * 0.11,
        0, h * 0.18,
      );

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = const LinearGradient(
          colors: [
            Color(0x8000E5FF),
            Color(0x997928CA),
            Color(0x10FF007F),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.28));

      canvas.drawPath(edgePath, linePaint);
    } else {
      // Light mode: TWO CLEARLY VISIBLE, RICHLY COLORED FLUID WAVES

      // Wave 1 (Secondary deeper wave - soft cyan/sky blue)
      final topWave1 = Path();
      topWave1.moveTo(0, 0);
      topWave1.lineTo(w, 0);
      topWave1.lineTo(w, h * 0.21);
      topWave1.cubicTo(
        w * 0.72, h * 0.27,
        w * 0.38, h * 0.13,
        0, h * 0.23,
      );
      topWave1.close();

      final paint1 = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xB093C5FD), // Rich, clearly visible sky-blue
            Color(0x60BFDBFE),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.30));

      canvas.drawPath(topWave1, paint1);

      // Wave 2 (Primary upper wave - vibrant azure/cyan)
      final topWave2 = Path();
      topWave2.moveTo(0, 0);
      topWave2.lineTo(w, 0);
      topWave2.lineTo(w, h * 0.15);
      topWave2.cubicTo(
        w * 0.64, h * 0.20,
        w * 0.32, h * 0.08,
        0, h * 0.17,
      );
      topWave2.close();

      final paint2 = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xD060A5FA), // Vibrant, crisp sky blue (popping against white-gray!)
            Color(0x8593C5FD),
            Color(0x15DBEAFE),
          ],
          stops: const [0.0, 0.60, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.24));

      canvas.drawPath(topWave2, paint2);
    }
  }

  void _drawBottomWave(Canvas canvas, double w, double h) {
    if (isDark) {
      final path = Path();
      path.moveTo(0, h);
      path.lineTo(w, h);
      path.lineTo(w, h * 0.90);
      path.cubicTo(
        w * 0.65, h * 0.98,
        w * 0.35, h * 0.86,
        0, h * 0.92,
      );
      path.close();

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: const [
            Color(0x40FF007F),
            Color(0x257928CA),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromLTWH(0, h * 0.85, w, h * 0.15));

      canvas.drawPath(path, paint);

      final edgePath = Path();
      edgePath.moveTo(0, h * 0.92);
      edgePath.cubicTo(
        w * 0.35, h * 0.86,
        w * 0.65, h * 0.98,
        w, h * 0.90,
      );

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..shader = const LinearGradient(
          colors: [
            Color(0x99FF007F),
            Color(0x669D4EDD),
            Color(0x1000E5FF),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.85, w, h * 0.15));

      canvas.drawPath(edgePath, linePaint);
    } else {
      // Light mode: CLEARLY VISIBLE, RICH MULTI-LAYERED PASTEL WAVES

      // Layer 1: Vibrant sky-blue wave sweeping from left across center
      final blueWave = Path();
      blueWave.moveTo(0, h);
      blueWave.lineTo(0, h * 0.93);
      blueWave.cubicTo(
        w * 0.22, h * 0.86,
        w * 0.46, h * 0.90,
        w * 0.78, h,
      );
      blueWave.close();

      final bluePaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: const [
            Color(0xD060A5FA), // Rich vibrant pastel sky-blue
            Color(0x8093C5FD),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.84, w * 0.78, h * 0.16));

      canvas.drawPath(blueWave, bluePaint);

      // Layer 2: Vibrant pastel lavender/violet wave sweeping across bottom-right
      final purpleWave = Path();
      purpleWave.moveTo(w * 0.22, h);
      purpleWave.cubicTo(
        w * 0.50, h * 0.89,
        w * 0.76, h * 0.84,
        w, h * 0.82,
      );
      purpleWave.lineTo(w, h);
      purpleWave.close();

      final purplePaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: const [
            Color(0xD5C084FC), // Rich, clearly visible pastel lavender
            Color(0x85DDD6FE),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(w * 0.22, h * 0.81, w * 0.78, h * 0.19));

      canvas.drawPath(purpleWave, purplePaint);

      // Layer 3: Soft pink/magenta accent wave for rich multi-tone depth
      final pinkWave = Path();
      pinkWave.moveTo(w * 0.45, h);
      pinkWave.cubicTo(
        w * 0.66, h * 0.91,
        w * 0.86, h * 0.87,
        w, h * 0.86,
      );
      pinkWave.lineTo(w, h);
      pinkWave.close();

      final pinkPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.centerLeft,
          colors: const [
            Color(0x85F472B6), // Soft pastel pink highlight
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(w * 0.45, h * 0.85, w * 0.55, h * 0.15));

      canvas.drawPath(pinkWave, pinkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveBackgroundPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.showDots != showDots ||
        oldDelegate.colors != colors;
  }
}
