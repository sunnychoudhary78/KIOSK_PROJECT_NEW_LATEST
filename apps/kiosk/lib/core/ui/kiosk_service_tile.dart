import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';

enum KioskServiceTileTone { standard, cosmic }

/// Organic wave painter at the bottom-right corner matching Athena card design language.
class _CardBottomWavePainter extends CustomPainter {
  const _CardBottomWavePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width * 0.40, size.height);
    path.cubicTo(
      size.width * 0.58,
      size.height * 0.98,
      size.width * 0.68,
      size.height * 0.55,
      size.width,
      size.height * 0.50,
    );
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CardBottomWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Horizontal service tile for home catalog.
/// Light mode: white card, organic pastel wave, 3D squircle icon, vertical separator, bold title, arrow circle.
/// Dark mode: cosmic gradient, violet glow, matching accent colors.
class KioskServiceTile extends StatefulWidget {
  const KioskServiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone = KioskServiceTileTone.standard,
    this.accent,
    this.gradientColors,
    this.waveColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final KioskServiceTileTone tone;
  final Color? accent;
  final List<Color>? gradientColors;
  final Color? waveColor;

  @override
  State<KioskServiceTile> createState() => _KioskServiceTileState();
}

class _KioskServiceTileState extends State<KioskServiceTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveAccent = widget.accent ?? const Color(0xFF0077B6);
    final grad = widget.gradientColors ??
        [effectiveAccent.withValues(alpha: 0.9), effectiveAccent];

    final effectiveWaveColor = isDark
        ? effectiveAccent.withValues(alpha: 0.18)
        : (widget.waveColor ?? effectiveAccent.withValues(alpha: 0.10));

    final cardDecoration = isDark
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF211747), Color(0xFF17102F)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: effectiveAccent.withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: effectiveAccent.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: Offset.zero,
              ),
            ],
          )
        : BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: effectiveAccent.withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: effectiveAccent.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              const BoxShadow(
                color: Color(0x06000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          );

    final titleColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtitleColor = isDark ? const Color(0xFFCBD2E1) : const Color(0xFF64748B);
    final arrowBg = isDark ? const Color(0xFF1C143F) : Colors.white;
    final arrowBorderColor = isDark
        ? effectiveAccent.withValues(alpha: 0.6)
        : effectiveAccent.withValues(alpha: 0.35);
    final arrowIconColor = effectiveAccent;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 140),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(24),
          splashColor: effectiveAccent.withValues(alpha: 0.12),
          highlightColor: effectiveAccent.withValues(alpha: 0.05),
          child: Ink(
            decoration: cardDecoration,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Organic bottom wave matching Athena reading cards
                  CustomPaint(
                    painter: _CardBottomWavePainter(color: effectiveWaveColor),
                    size: Size.infinite,
                  ),

                  // 2. Card Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 3D Squircle Icon with glossy border & colored glow
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: grad,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.40),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: grad.last.withValues(alpha: 0.40),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              widget.icon,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Vertical Separator Line
                        Container(
                          width: 1,
                          height: 48,
                          color: isDark
                              ? const Color(0xFF2E2452)
                              : const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 16),

                        // Title + Subtitle
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: titleColor,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                widget.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Circular arrow button
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: arrowBg,
                            border: Border.all(
                              color: arrowBorderColor,
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: effectiveAccent.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 19,
                              color: arrowIconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
