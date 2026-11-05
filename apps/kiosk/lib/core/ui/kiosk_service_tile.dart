import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';

enum KioskServiceTileTone { standard, cosmic }

/// Horizontal service tile exactly matching the reference images.
/// Light mode: white card, thin gray border, accent-colored squircle icon, arrow circle.
/// Dark mode: dark navy card, subtle dark border, same icon, brighter arrow.
class KioskServiceTile extends StatelessWidget {
  const KioskServiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone = KioskServiceTileTone.standard,
    this.accent,
    this.gradientColors,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final KioskServiceTileTone tone;
  final Color? accent;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final grad = gradientColors ??
        (accent != null
            ? [accent!.withValues(alpha: 0.9), accent!]
            : [const Color(0xFF00B4D8), const Color(0xFF0077B6)]);

    // Exactly matching user specification:
    // .service-card {
    //   background: linear-gradient(135deg, #211747 0%, #17102f 100%);
    //   border: 1px solid #7445bd;
    //   border-radius: 24px;
    //   box-shadow: 0 0 18px rgba(139, 53, 255, 0.18);
    // }
    final cardDecoration = isDark
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF211747), Color(0xFF17102F)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF7445BD), width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E8B35FF), // rgba(139, 53, 255, 0.18)
                blurRadius: 18,
                offset: Offset.zero,
              ),
            ],
          )
        : BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2EBF5), width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C1B2B4F),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          );

    final titleColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtitleColor = isDark ? const Color(0xFFCBD2E1) : const Color(0xFF667085);
    final arrowBg = isDark ? const Color(0xFF1C143F) : Colors.white;
    final arrowBorderColor = isDark
        ? const Color(0xFF7445BD)
        : const Color(0xFFD6C8F0);
    final arrowIconColor = isDark ? Colors.white : const Color(0xFF7445BD);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: (accent ?? colors.accentMagenta).withValues(alpha: 0.10),
        highlightColor: (accent ?? colors.accentMagenta).withValues(alpha: 0.05),
        child: Ink(
          decoration: cardDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Subtle gradient wash at bottom of card (Image 1 light mode)
                if (!isDark)
                  Positioned(
                    left: 0, right: 0, bottom: 0, height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topCenter,
                          colors: [
                            (accent ?? const Color(0xFF00B4D8)).withValues(alpha: 0.07),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                // Card content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Squircle Icon (matches reference image exactly)
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: grad,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: grad.last.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(icon, size: 36, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 18),

                      // Title + Subtitle
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: titleColor,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Circular arrow button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: arrowBg,
                          border: Border.all(color: arrowBorderColor, width: 1.2),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
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
    );
  }
}
