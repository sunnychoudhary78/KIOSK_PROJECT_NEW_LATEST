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
    this.statusLabel,
    this.statusBlocked = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final KioskServiceTileTone tone;
  final Color? accent;
  final List<Color>? gradientColors;
  final Color? waveColor;

  /// When set, shown as a badge (e.g. Under maintenance / Out of service).
  final String? statusLabel;

  /// When true, tap is blocked and the tile looks unavailable.
  final bool statusBlocked;

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

    final blocked = widget.statusBlocked;
    final statusLabel = widget.statusLabel;
    final titleColor = blocked
        ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
        : (isDark ? Colors.white : const Color(0xFF101828));
    final subtitleColor = isDark ? const Color(0xFFCBD2E1) : const Color(0xFF64748B);
    final arrowBg = isDark ? const Color(0xFF1C143F) : Colors.white;
    final arrowBorderColor = isDark
        ? effectiveAccent.withValues(alpha: blocked ? 0.3 : 0.6)
        : effectiveAccent.withValues(alpha: blocked ? 0.2 : 0.35);
    final arrowIconColor = blocked ? subtitleColor : effectiveAccent;
    final statusColor = statusLabel == 'Out of service'
        ? const Color(0xFFDC2626)
        : const Color(0xFFD97706);

    return Opacity(
      opacity: blocked ? 0.78 : 1,
      child: AnimatedScale(
        scale: _pressed && !blocked ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: blocked ? null : widget.onTap,
            onTapDown: blocked ? null : (_) => setState(() => _pressed = true),
            onTapUp: blocked ? null : (_) => setState(() => _pressed = false),
            onTapCancel: blocked ? null : () => setState(() => _pressed = false),
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
                    CustomPaint(
                      painter: _CardBottomWavePainter(color: effectiveWaveColor),
                      size: Size.infinite,
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Scale tile chrome to the cell size (laptop vs 4:3 kiosk).
                        final heightScale =
                            (constraints.maxHeight / 155).clamp(0.62, 1.15);
                        final widthScale =
                            (constraints.maxWidth / 420).clamp(0.62, 1.15);
                        final s = heightScale < widthScale ? heightScale : widthScale;
                        final iconBox = 68.0 * s;
                        final iconGlyph = 34.0 * s;
                        final titleSize = 25.0 * s;
                        final subtitleSize = 16.0 * s;
                        final arrowBox = 42.0 * s;
                        final hPad = 20.0 * s;
                        final vPad = 14.0 * s;
                        final gap = 16.0 * s;
                        final showDivider = constraints.maxWidth > 280;
                        final showArrow = constraints.maxWidth > 240;

                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: hPad,
                            vertical: vPad,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: iconBox,
                                height: iconBox,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20 * s),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: blocked
                                        ? [
                                            const Color(0xFF94A3B8),
                                            const Color(0xFF64748B),
                                          ]
                                        : grad,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.40),
                                    width: 1.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (blocked
                                              ? const Color(0xFF64748B)
                                              : grad.last)
                                          .withValues(alpha: 0.40),
                                      blurRadius: 14 * s,
                                      offset: Offset(0, 5 * s),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    blocked ? Icons.block_rounded : widget.icon,
                                    size: iconGlyph,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (showDivider) ...[
                                SizedBox(width: gap),
                                Container(
                                  width: 1,
                                  height: 48 * s,
                                  color: isDark
                                      ? const Color(0xFF2E2452)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ],
                              SizedBox(width: gap),
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
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                        color: titleColor,
                                        height: 1.15,
                                      ),
                                    ),
                                    SizedBox(height: 5 * s),
                                    Text(
                                      blocked && statusLabel != null
                                          ? statusLabel
                                          : widget.subtitle,
                                      maxLines: constraints.maxHeight < 110 ? 1 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: subtitleSize,
                                        fontWeight: FontWeight.w500,
                                        height: 1.35,
                                        color: blocked
                                            ? statusColor
                                            : subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (showArrow) ...[
                                SizedBox(width: 12 * s),
                                if (statusLabel != null && blocked)
                                  Flexible(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10 * s,
                                        vertical: 6 * s,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: isDark ? 0.22 : 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: statusColor.withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 12 * s,
                                          fontWeight: FontWeight.w700,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: arrowBox,
                                    height: arrowBox,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: arrowBg,
                                      border: Border.all(
                                        color: arrowBorderColor,
                                        width: 1.4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: effectiveAccent.withValues(
                                            alpha: 0.12,
                                          ),
                                          blurRadius: 8 * s,
                                          offset: Offset(0, 2 * s),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 19 * s,
                                        color: arrowIconColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
