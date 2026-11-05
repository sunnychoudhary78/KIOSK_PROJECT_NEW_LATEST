import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/astrology/application/palm_quality_checker.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_assets.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/palm_overlay.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/palm_seal_ring.dart';

/// Top bar stepper for Palm Reading: (1) Scan — (2) Analyze — (3) Insights.
class PalmTopStepper extends StatelessWidget {
  const PalmTopStepper({super.key, this.activeStep = 0});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1B2E)
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF3B2F50)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9333EA).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepItem(1, 'Scan', activeStep == 0, activeStep > 0),
          _divider(activeStep >= 1),
          _stepItem(2, 'Analyze', activeStep == 1, activeStep > 1),
          _divider(activeStep >= 2),
          _stepItem(3, 'Insights', activeStep == 2, false),
        ],
      ),
    );
  }

  Widget _stepItem(int number, String label, bool active, bool passed) {
    final activeColor = const Color(0xFFEC4899);
    final passedColor = const Color(0xFF8B5CF6);
    final inactiveColor = const Color(0xFF64748B);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? activeColor
                : (passed ? passedColor : Colors.transparent),
            border: (active || passed)
                ? null
                : Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: (active || passed) ? Colors.white : inactiveColor,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? activeColor
                : (passed ? passedColor : inactiveColor),
          ),
        ),
      ],
    );
  }

  Widget _divider(bool passed) {
    return Container(
      width: 28,
      height: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: passed ? const Color(0xFFEC4899) : const Color(0xFFE2E8F0),
    );
  }
}

/// 3-Column Position Your Palm interface matching the reference design.
///
/// Left: Scan Instructions card
/// Center: Circular camera viewport with cosmic orbital ring, cyan brackets, holographic palm & status pills
/// Right: Palm Scan status card with holographic palm, analyzing text & progress bar
class PalmCaptureViewport extends StatelessWidget {
  const PalmCaptureViewport({
    super.key,
    required this.camera,
    required this.cameraReady,
    required this.cameraError,
    required this.quality,
    required this.onRetryCamera,
    required this.orbit,
    required this.pulse,
    required this.seal,
    required this.sweep,
  });

  final CameraController? camera;
  final bool cameraReady;
  final String? cameraError;
  final PalmQualityResult? quality;
  final VoidCallback onRetryCamera;
  final Animation<double> orbit;
  final Animation<double> pulse;
  final Animation<double> seal;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final ready = quality?.ok == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Left Card: Scan Instructions
          Expanded(
            flex: 3,
            child: _ScanInstructionsCard(),
          ),
          const SizedBox(width: 20),

          // 2. Center Column: Circular Viewfinder & Quality Pills
          Expanded(
            flex: 4,
            child: _CenterCameraSection(
              camera: camera,
              cameraReady: cameraReady,
              cameraError: cameraError,
              quality: quality,
              onRetryCamera: onRetryCamera,
              orbit: orbit,
              pulse: pulse,
              seal: seal,
              sweep: sweep,
              ready: ready,
            ),
          ),
          const SizedBox(width: 20),

          // 3. Right Card: Palm Scan Status
          Expanded(
            flex: 3,
            child: _PalmScanStatusCard(
              quality: quality,
              sweep: sweep,
            ),
          ),
        ],
      ),
    );
  }
}

/// Left card with instructions:
/// - Keep your palm open
/// - Place it inside the circle
/// - Hold still for a few seconds
/// - Ensure good lighting (highlighted lavender capsule)
class _ScanInstructionsCard extends StatelessWidget {
  const _ScanInstructionsCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3B2F50) : const Color(0xFFF1F5F9);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9333EA).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFFEC4899),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Scan Instructions',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4 Instruction Items
          _instructionRow(
            icon: Icons.pan_tool_outlined,
            text: 'Keep your palm open',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _instructionRow(
            icon: Icons.crop_free_rounded,
            text: 'Place it inside the circle',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _instructionRow(
            icon: Icons.timer_outlined,
            text: 'Hold still for a few seconds',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _instructionRow(
            icon: Icons.wb_sunny_outlined,
            text: 'Ensure good lighting',
            highlighted: true,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _instructionRow({
    required IconData icon,
    required String text,
    required bool isDark,
    bool highlighted = false,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    final content = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: highlighted
                ? const Color(0xFF9333EA)
                : (isDark ? const Color(0xFF2A233D) : const Color(0xFFF3E8FF)),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: highlighted ? Colors.white : const Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );

    if (highlighted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2E1C48), const Color(0xFF381E44)]
                : [const Color(0xFFEDE9FE), const Color(0xFFFCE7F3)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFC084FC).withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: content,
    );
  }
}

/// Center Column:
/// - Circular camera viewfinder with orbital gradient ring, sparkle star at top, cyan corner brackets, palm silhouette & sweep
/// - Row with 3 purple pills: [✓ Hand] [✓ Lighting] [✓ Position]
/// - Green success pill banner: [✓ Palm captured!]
class _CenterCameraSection extends StatelessWidget {
  const _CenterCameraSection({
    required this.camera,
    required this.cameraReady,
    required this.cameraError,
    required this.quality,
    required this.onRetryCamera,
    required this.orbit,
    required this.pulse,
    required this.seal,
    required this.sweep,
    required this.ready,
  });

  final CameraController? camera;
  final bool cameraReady;
  final String? cameraError;
  final PalmQualityResult? quality;
  final VoidCallback onRetryCamera;
  final Animation<double> orbit;
  final Animation<double> pulse;
  final Animation<double> seal;
  final Animation<double> sweep;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Circular Viewport (diameter ~260)
        SizedBox(
          width: 260,
          height: 260,
          child: AnimatedBuilder(
            animation: Listenable.merge([orbit, pulse, seal, sweep]),
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Cosmic Gradient Ring with top Sparkle Star
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CosmicViewfinderRingPainter(
                        orbitAngle: orbit.value * math.pi * 2,
                        ready: ready,
                      ),
                    ),
                  ),

                  // Circular camera viewport hole
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: ClipOval(
                      child: Container(
                        color: Colors.black,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Live camera preview or dark fallback
                            if (cameraReady && camera != null)
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: camera!.value.previewSize?.height ?? 1280.0,
                                  height: camera!.value.previewSize?.width ?? 720.0,
                                  child: CameraPreview(camera!),
                                ),
                              )
                            else
                              Container(
                                color: const Color(0xFF0F172A),
                                child: const Center(
                                  child: Icon(
                                    Icons.videocam_outlined,
                                    color: Color(0xFF475569),
                                    size: 40,
                                  ),
                                ),
                              ),

                            // Cyan corner brackets [   ] inside viewport
                            Center(
                              child: SizedBox(
                                width: 140,
                                height: 160,
                                child: CustomPaint(
                                  painter: _CornerBracketsPainter(
                                    color: const Color(0xFF06B6D4),
                                    strokeWidth: 3.5,
                                    bracketLength: 22,
                                  ),
                                ),
                              ),
                            ),

                            // Holographic Hand silhouette guide
                            Center(
                              child: Opacity(
                                opacity: ready ? 0.90 : 0.65,
                                child: SizedBox(
                                  width: 130,
                                  height: 150,
                                  child: const AstrologyAssetImage(
                                    asset: AstrologyAssets.palmGuide,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),

                            // Sweep scan line if ready
                            if (ready)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _ScanSweepPainter(t: sweep.value),
                                ),
                              ),

                            // Seal animation ring
                            Positioned.fill(
                              child: PalmSealRing(progress: seal.value),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // 3 Purple Status Pills: [✓ Hand] [✓ Lighting] [✓ Position]
        _QualityPillsRow(quality: quality),
        const SizedBox(height: 10),

        // Green Success Banner: [✓ Palm captured!]
        _PalmCapturedBanner(ready: ready),
      ],
    );
  }
}

/// 3 Purple status pills matching the reference screenshot:
/// Solid purple capsule when valid, white check + white label.
class _QualityPillsRow extends StatelessWidget {
  const _QualityPillsRow({required this.quality});

  final PalmQualityResult? quality;

  @override
  Widget build(BuildContext context) {
    final q = quality;
    final handOk = q != null &&
        q.skinRatio >= PalmQualityChecker.manualMinInsideSkinRatio &&
        q.fingerSkinRatio >= PalmQualityChecker.manualMinFingerSkinRatio;
    final lightOk = q != null &&
        q.brightness >= PalmQualityChecker.minBrightness &&
        q.brightness <= PalmQualityChecker.maxBrightness &&
        q.blur >= PalmQualityChecker.manualMinBlur;
    final positionOk = q?.ok == true ||
        (q != null &&
            q.centroidOk &&
            q.skinRatio - q.outsideSkinRatio >=
                PalmQualityChecker.manualMinSkinContrast &&
            q.outsideSkinRatio <=
                PalmQualityChecker.manualMaxOutsideSkinRatio &&
            q.roiSkinRatio <= PalmQualityChecker.manualMaxRoiSkinRatio &&
            handOk);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _singlePill('Hand', handOk),
        const SizedBox(width: 8),
        _singlePill('Lighting', lightOk),
        const SizedBox(width: 8),
        _singlePill('Position', positionOk),
      ],
    );
  }

  Widget _singlePill(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFF7C3AED) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: ok
            ? [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_rounded : Icons.radio_button_unchecked,
            size: 15,
            color: ok ? Colors.white : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ok ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mint Green Success Banner: [✓ Palm captured!]
class _PalmCapturedBanner extends StatelessWidget {
  const _PalmCapturedBanner({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: ready ? 1.0 : 0.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.check_rounded,
              color: Color(0xFF15803D),
              size: 16,
            ),
            SizedBox(width: 6),
            Text(
              'Palm captured!',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Right Card: Palm Scan Status Card
/// - Cyan corner brackets [   ] around mini holographic palm
/// - Title: Palm Scan
/// - Subtitle: Analyzing palm lines...
/// - Pink/purple gradient progress bar
class _PalmScanStatusCard extends StatelessWidget {
  const _PalmScanStatusCard({
    required this.quality,
    required this.sweep,
  });

  final PalmQualityResult? quality;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3B2F50) : const Color(0xFFF1F5F9);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9333EA).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Holographic Palm Preview inside cyan brackets
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Cyan corner brackets [   ]
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CornerBracketsPainter(
                      color: const Color(0xFF06B6D4),
                      strokeWidth: 3.5,
                      bracketLength: 20,
                    ),
                  ),
                ),
                // Holographic mini palm silhouette
                Center(
                  child: SizedBox(
                    width: 70,
                    height: 85,
                    child: Opacity(
                      opacity: 0.75,
                      child: const AstrologyAssetImage(
                        asset: AstrologyAssets.palmGuide,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            'Palm Scan',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            'Analyzing palm lines...',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),

          // Gradient Progress Bar
          AnimatedBuilder(
            animation: sweep,
            builder: (context, _) {
              final progress = (0.35 + sweep.value * 0.55).clamp(0.0, 1.0);
              return Container(
                height: 7,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A233D) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 4-corner bracket painter [   ] in cyan (#06B6D4).
class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter({
    this.color = const Color(0xFF06B6D4),
    this.strokeWidth = 3.5,
    this.bracketLength = 22.0,
    this.cornerRadius = 6.0,
  });

  final Color color;
  final double strokeWidth;
  final double bracketLength;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final len = bracketLength;
    final r = cornerRadius;

    // Top-left
    final pathTL = Path()
      ..moveTo(0, len)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(len, 0);
    canvas.drawPath(pathTL, paint);

    // Top-right
    final pathTR = Path()
      ..moveTo(w - len, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, len);
    canvas.drawPath(pathTR, paint);

    // Bottom-left
    final pathBL = Path()
      ..moveTo(0, h - len)
      ..lineTo(0, h - r)
      ..quadraticBezierTo(0, h, r, h)
      ..lineTo(len, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-right
    final pathBR = Path()
      ..moveTo(w - len, h)
      ..lineTo(w - r, h)
      ..quadraticBezierTo(w, h, w, h - r)
      ..lineTo(w, h - len);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.bracketLength != bracketLength;
}

/// Circular orbital viewfinder ring with multi-color gradient and sparkle star at top.
class _CosmicViewfinderRingPainter extends CustomPainter {
  const _CosmicViewfinderRingPainter({
    required this.orbitAngle,
    required this.ready,
  });

  final double orbitAngle;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.5 - 6;

    // 1. Soft glowing outer backdrop
    final glowPaint = Paint()
      ..color = const Color(0xFFC084FC).withValues(alpha: ready ? 0.35 : 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, radius, glowPaint);

    // 2. Base subtle ring
    final basePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5;
    canvas.drawCircle(center, radius, basePaint);

    // 3. Multi-color sweep gradient ring
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      transform: GradientRotation(orbitAngle),
      colors: const [
        Color(0xFF8B5CF6), // Violet
        Color(0xFF3B82F6), // Blue
        Color(0xFFEC4899), // Pink
        Color(0xFF8B5CF6), // Violet
      ],
      stops: const [0.0, 0.38, 0.78, 1.0],
    );
    final gradientPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 1.85, false, gradientPaint);

    // 4. Accent sparkle star at the top (angle -pi/2)
    final starCenter = Offset(center.dx, center.dy - radius);
    _drawSparkleStar(canvas, starCenter, const Color(0xFFEC4899), 6.5);
  }

  void _drawSparkleStar(Canvas canvas, Offset c, Color color, double radius) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(c.dx, c.dy - radius * 1.5);
    path.quadraticBezierTo(c.dx, c.dy, c.dx + radius * 1.5, c.dy);
    path.quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + radius * 1.5);
    path.quadraticBezierTo(c.dx, c.dy, c.dx - radius * 1.5, c.dy);
    path.quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - radius * 1.5);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CosmicViewfinderRingPainter oldDelegate) =>
      oldDelegate.orbitAngle != orbitAngle || oldDelegate.ready != ready;
}

/// Scanning beam sweeping across the viewport.
class _ScanSweepPainter extends CustomPainter {
  const _ScanSweepPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * (0.2 + t * 0.6);

    final trail = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF06B6D4).withValues(alpha: 0.0),
          const Color(0xFF06B6D4).withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromLTWH(0, y - 28, size.width, 28));
    canvas.drawRect(Rect.fromLTWH(0, y - 28, size.width, 28), trail);

    final beam = Paint()
      ..color = const Color(0xFF00F2FE)
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), beam);
  }

  @override
  bool shouldRepaint(covariant _ScanSweepPainter oldDelegate) => oldDelegate.t != t;
}

/// Fallback / legacy support for PalmFlowStepRail
class PalmFlowStepRail extends StatelessWidget {
  const PalmFlowStepRail({super.key, required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return PalmTopStepper(activeStep: activeIndex);
  }
}

/// Quality chips export for external testing
class PalmQualityChips extends StatelessWidget {
  const PalmQualityChips({
    super.key,
    required this.quality,
    this.compact = false,
  });

  final PalmQualityResult? quality;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _QualityPillsRow(quality: quality);
  }
}
