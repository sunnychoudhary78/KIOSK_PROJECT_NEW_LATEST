import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';

/// 3D Isometric Kiosk Terminal Graphic (Image 1) without unwanted background blobs/rings.
class KioskTerminalGraphic extends StatelessWidget {
  const KioskTerminalGraphic({super.key, this.size = 130});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: size * 1.05,
      height: size,
      child: Center(
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY(-0.18)
            ..rotateX(0.08),
          alignment: Alignment.center,
          child: Container(
            width: size * 0.62,
            height: size * 0.92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF261D4E),
                        Color(0xFF1B133E),
                        Color(0xFF130D30),
                      ]
                    : const [
                        Colors.white,
                        Color(0xFFFBF1F7),
                        Color(0xFFF3D2E7),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? AthenaColors.neonPink : const Color(0xFFE6007A))
                      .withValues(alpha: isDark ? 0.35 : 0.18),
                  blurRadius: 18,
                  offset: const Offset(4, 8),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? AthenaColors.neonPink.withValues(alpha: 0.6)
                    : Colors.white,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                // Angled Touch Screen
                Container(
                  margin: const EdgeInsets.all(7),
                  height: size * 0.44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2B1842),
                        Color(0xFF1A0F2E),
                      ],
                    ),
                    border: Border.all(
                      color: AthenaColors.neonPink.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AthenaColors.neonPink, width: 1.5),
                      ),
                      child: const Center(
                        child: Text(
                          'T',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Kiosk Card/Receipt Slots
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        width: 18,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0077B6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 18,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AthenaColors.magenta,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Bottom Scanner / Cash Dispenser Slot
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  height: 14,
                  width: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D081F),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: colors.cardBorder.withValues(alpha: 0.3),
                    ),
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
