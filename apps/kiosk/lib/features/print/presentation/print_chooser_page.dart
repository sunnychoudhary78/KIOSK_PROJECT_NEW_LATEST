import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class PrintChooserPage extends ConsumerWidget {
  const PrintChooserPage({super.key});

  Future<void> _endSession(WidgetRef ref) {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: 'Print Documents',
        titleIcon: Icons.print_rounded,
        onHome: () => _endSession(ref),
        body: kioskPrintingPaused(ref)
            ? const KioskPrintingPaused()
            : Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Page Header ──────────────────────────────────────────
                    Row(
                      children: [
                        // Print icon squircle
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFF4DC4), Color(0xFFE6007A)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE6007A)
                                    .withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.print_rounded,
                                size: 28, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 18),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'How do you want to ',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        color: colors.textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Print?',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        color: colors.accentMagenta,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Accent underline
                              Container(
                                width: 44,
                                height: 3.5,
                                decoration: BoxDecoration(
                                  color: colors.accentMagenta,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Scan a QR, enter an OTP, or print from DigiLocker.',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Privacy disclaimer banner (green, matching mockup Image 5)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A)
                            .withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF16A34A)
                              .withValues(alpha: isDark ? 0.4 : 0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'We do not save your documents. Files are used only to print this session, then removed from this kiosk.',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── 3 Print Method Cards with prominent 3D illustrations ─
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _PrintMethodCard(
                              assetPath:
                                  'assets/new_theme_icons/how_do_you_print/qr_scan_phone.png',
                              title: 'Print from QR',
                              subtitle: 'Scan a QR and upload in the browser',
                              accentColor: const Color(0xFF0084FF),
                              waveColor: const Color(0xFFD6E9FC),
                              cardGradient: const [
                                Color(0xFFF5FAFF),
                                Color(0xFFFFFFFF),
                              ],
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.quickPrint),
                              colors: colors,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _PrintMethodCard(
                              assetPath:
                                  'assets/new_theme_icons/how_do_you_print/otp_password_phone.png',
                              title: 'I have an OTP',
                              subtitle: 'Enter the code sent to the mobile app',
                              accentColor: const Color(0xFFE6007A),
                              waveColor: const Color(0xFFFBD7E8),
                              cardGradient: const [
                                Color(0xFFFFF6FA),
                                Color(0xFFFFFFFF),
                              ],
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.otpPrint),
                              colors: colors,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _PrintMethodCard(
                              assetPath:
                                  'assets/new_theme_icons/how_do_you_print/digilocker.png',
                              title: 'DigiLocker Print',
                              subtitle: 'Sign in and print government documents',
                              accentColor: const Color(0xFF7C3AED),
                              waveColor: const Color(0xFFE8DEFA),
                              cardGradient: const [
                                Color(0xFFFAF7FE),
                                Color(0xFFFFFFFF),
                              ],
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.digilockerPrint),
                              colors: colors,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Back button bottom left
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _endSession(ref),
                            borderRadius: BorderRadius.circular(26),
                            child: Ink(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1C143F)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF7445BD)
                                      : const Color(0xFFD0D5DD),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? const Color(0x2E8B35FF)
                                        : Colors.black
                                            .withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    size: 18,
                                    color: colors.textPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Back',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Vertical print method card with prominent 3D illustration and bottom wave wash
class _PrintMethodCard extends StatelessWidget {
  const _PrintMethodCard({
    required this.assetPath,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.waveColor,
    required this.cardGradient,
    required this.onTap,
    required this.colors,
    required this.isDark,
  });

  final String assetPath;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color waveColor;
  final List<Color> cardGradient;
  final VoidCallback onTap;
  final AthenaColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardBorder = isDark
        ? accentColor.withValues(alpha: 0.35)
        : const Color(0xFFE2EBF5);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: accentColor.withValues(alpha: 0.12),
        highlightColor: accentColor.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF211747), const Color(0xFF17102F)]
                  : cardGradient,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? accentColor.withValues(alpha: 0.18)
                    : const Color(0x0E1B2B4F),
                blurRadius: isDark ? 20 : 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Bottom organic wave shape
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 120,
                  child: CustomPaint(
                    painter: _CardBottomWavePainter(
                      waveColor: isDark
                          ? waveColor.withValues(alpha: 0.22)
                          : waveColor,
                    ),
                  ),
                ),

                // Card content
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                  child: Column(
                    children: [
                      // Prominent 3D illustration centered in upper space
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(
                              maxHeight: 180,
                              maxWidth: 180,
                            ),
                            child: Image.asset(
                              assetPath,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 56,
                                  color: colors.textSecondary,
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.2,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: colors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Solid circle button with white arrow
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.42),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 22,
                            color: Colors.white,
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

/// Organic flowing wave at the bottom of the card
class _CardBottomWavePainter extends CustomPainter {
  final Color waveColor;
  const _CardBottomWavePainter({required this.waveColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Back wave layer (subtle, softer)
    final backPaint = Paint()
      ..color = waveColor.withValues(alpha: 0.50)
      ..style = PaintingStyle.fill;

    final backPath = Path();
    backPath.moveTo(0, size.height * 0.45);
    backPath.cubicTo(
      size.width * 0.30, size.height * 0.70,
      size.width * 0.65, size.height * 0.25,
      size.width, size.height * 0.52,
    );
    backPath.lineTo(size.width, size.height);
    backPath.lineTo(0, size.height);
    backPath.close();
    canvas.drawPath(backPath, backPaint);

    // Front wave layer (prominent, matching mock image)
    final frontPaint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill;

    final frontPath = Path();
    frontPath.moveTo(0, size.height * 0.68);
    frontPath.cubicTo(
      size.width * 0.32, size.height * 0.40,
      size.width * 0.68, size.height * 0.85,
      size.width, size.height * 0.60,
    );
    frontPath.lineTo(size.width, size.height);
    frontPath.lineTo(0, size.height);
    frontPath.close();
    canvas.drawPath(frontPath, frontPaint);
  }

  @override
  bool shouldRepaint(covariant _CardBottomWavePainter oldDelegate) =>
      oldDelegate.waveColor != waveColor;
}
