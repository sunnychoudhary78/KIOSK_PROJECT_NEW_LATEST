import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/ads/presentation/kiosk_wait_ads.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_assets.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/glass_panel.dart';

/// Casting wait: ads behind a glass “chart casting” overlay (keeps session hold).
class AstrologyCastingView extends StatefulWidget {
  const AstrologyCastingView({
    super.key,
    this.lines,
    this.accent = AstrologyColors.gold,
  });

  /// Rotating status lines. Defaults to the palm-reading copy.
  final List<String>? lines;
  final Color accent;

  @override
  State<AstrologyCastingView> createState() => _AstrologyCastingViewState();
}

class _AstrologyCastingViewState extends State<AstrologyCastingView>
    with TickerProviderStateMixin {
  static const _defaultLines = [
    'Reading your palm lines…',
    'Mapping Lagna & Nakshatra…',
    'Weaving your period guidance…',
  ];

  List<String> get _lines =>
      (widget.lines == null || widget.lines!.isEmpty) ? _defaultLines : widget.lines!;

  late final AnimationController _orbit;
  late final AnimationController _copy;
  int _lineIndex = 0;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
    _copy = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _lineIndex = (_lineIndex + 1) % _lines.length);
          _copy.forward(from: 0);
        }
      });
    _copy.forward();
  }

  @override
  void dispose() {
    _orbit.dispose();
    _copy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        const Opacity(
          opacity: 0.42,
          child: KioskWaitAds(message: 'Preparing your reading…'),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: GlassPanel(
              padding: const EdgeInsets.fromLTRB(36, 36, 36, 32),
              borderColor: widget.accent.withValues(alpha: 0.45),
              color: isDark ? const Color(0xFF131126).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.94),
              borderRadius: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Double Orbiting Planetary Rings
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: AnimatedBuilder(
                      animation: _orbit,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _OrbitPainter(
                            t: _orbit.value,
                            color: widget.accent,
                          ),
                          child: Center(
                            child: Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: widget.accent.withValues(alpha: 0.75),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.accent.withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const ClipOval(
                                child: AstrologyAssetImage(
                                  asset: AstrologyAssets.sealMedallion,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Cosmic Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: widget.accent),
                        const SizedBox(width: 8),
                        Text(
                          'ALIGNING THE STARS',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w700,
                            color: widget.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Rotating status message
                  SizedBox(
                    height: 38,
                    child: AnimatedBuilder(
                      animation: _copy,
                      builder: (context, _) {
                        final t = Curves.easeInOut.transform(_copy.value);
                        final opacity = t < 0.15
                            ? t / 0.15
                            : t > 0.85
                                ? (1 - t) / 0.15
                                : 1.0;
                        return Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Text(
                            _lines[_lineIndex],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              height: 1.35,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Shimmering progress bar
                  Container(
                    width: 220,
                    height: 5,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: AnimatedBuilder(
                      animation: _orbit,
                      builder: (context, _) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.3 + 0.65 * ((math.sin(_orbit.value * math.pi * 2) + 1) / 2),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: LinearGradient(
                                colors: [
                                  widget.accent.withValues(alpha: 0.5),
                                  widget.accent,
                                  const Color(0xFFFBBF24),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.accent.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide * 0.46;
    final innerRadius = size.shortestSide * 0.35;

    // Outer Orbit Ring
    final outerRing = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, outerRadius, outerRing);

    // Inner Orbit Ring
    final innerRing = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, innerRadius, innerRing);

    // Outer Planets (clockwise)
    final planetPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      final angle = (t * math.pi * 2) + (i * math.pi * 2 / 6);
      final p = Offset(
        center.dx + math.cos(angle) * outerRadius,
        center.dy + math.sin(angle) * outerRadius,
      );
      planetPaint.color = color.withValues(alpha: 0.45 + (i % 3) * 0.22);
      canvas.drawCircle(p, i.isEven ? 4.5 : 3.0, planetPaint);
    }

    // Inner Planets (counter-clockwise)
    for (var i = 0; i < 4; i++) {
      final angle = (-t * math.pi * 2 * 1.3) + (i * math.pi * 2 / 4);
      final p = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      planetPaint.color = const Color(0xFFFBBF24).withValues(alpha: 0.65);
      canvas.drawCircle(p, 3.2, planetPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}
