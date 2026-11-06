import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skp_kiosk/core/ui/kiosk_buttons.dart';
import 'package:skp_kiosk/core/ui/kiosk_status.dart';

/// Accents for the print choice cards. Each choice keeps its own color.
abstract final class KioskPrintChoiceAccents {
  static const Color bw = Color(0xFF64748B);
  static const Color color = Color(0xFFD4894A);
  static const Color phone = Color(0xFF3D6BFF);
  static const Color pay = Color(0xFFC8962E);
}

class _PrintChoiceWavePainter extends CustomPainter {
  const _PrintChoiceWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.40, size.height)
      ..cubicTo(
        size.width * 0.58,
        size.height * 0.98,
        size.width * 0.68,
        size.height * 0.55,
        size.width,
        size.height * 0.50,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PrintChoiceWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Headline, subtitle, and two equal choice cards.
class KioskPrintChoiceBody extends StatelessWidget {
  const KioskPrintChoiceBody({
    super.key,
    required this.headline,
    required this.subtitle,
    required this.left,
    required this.right,
    this.error,
  });

  final String headline;
  final String subtitle;
  final Widget left;
  final Widget right;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            headline,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: isDark ? const Color(0xFFCBD2E1) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Row(
              children: [
                Expanded(child: left),
                const SizedBox(width: 20),
                Expanded(child: right),
              ],
            ),
          ),
          if (error != null && error!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            KioskStatusBanner(
              message: error!,
              tone: KioskBannerTone.danger,
              icon: Icons.error_outline,
            ),
          ],
        ],
      ),
    );
  }
}

/// Tall tap card using the same surface, wave, and icon as the home tiles.
class KioskPrintChoiceCard extends StatefulWidget {
  const KioskPrintChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  State<KioskPrintChoiceCard> createState() => _KioskPrintChoiceCardState();
}

class _KioskPrintChoiceCardState extends State<KioskPrintChoiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accent;
    final wave = isDark
        ? accent.withValues(alpha: 0.18)
        : accent.withValues(alpha: 0.10);
    final titleColor = isDark ? Colors.white : const Color(0xFF101828);
    final subtitleColor =
        isDark ? const Color(0xFFCBD2E1) : const Color(0xFF64748B);
    final arrowBg = isDark ? const Color(0xFF1C143F) : Colors.white;

    final decoration = isDark
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF211747), Color(0xFF17102F)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent.withValues(alpha: enabled ? 0.5 : 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: enabled ? 0.22 : 0.06),
                blurRadius: 18,
              ),
            ],
          )
        : BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent.withValues(alpha: enabled ? 0.22 : 0.1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: enabled ? 0.08 : 0.03),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: AnimatedScale(
        scale: _pressed && enabled ? 0.985 : 1,
        duration: const Duration(milliseconds: 140),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: widget.onPressed,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
            borderRadius: BorderRadius.circular(24),
            splashColor: accent.withValues(alpha: 0.12),
            highlightColor: accent.withValues(alpha: 0.05),
            child: Ink(
              decoration: decoration,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _PrintChoiceWavePainter(color: wave),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  accent.withValues(alpha: 0.9),
                                  accent,
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.40),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.40),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(widget.icon, size: 34, color: Colors.white),
                          ),
                          const Spacer(),
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1.15,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: arrowBg,
                                border: Border.all(
                                  color: accent.withValues(
                                    alpha: isDark ? 0.6 : 0.35,
                                  ),
                                  width: 1.4,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 19,
                                color: accent,
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
      ),
    );
  }
}

/// UPI explanation on the left and a scannable QR on the right.
class KioskUpiPayPanel extends StatelessWidget {
  const KioskUpiPayPanel({
    super.key,
    required this.detail,
    required this.followUp,
    required this.qrImageUrl,
    this.fallbackUrl = '',
    this.notice,
    this.error,
  });

  final String detail;
  final String followUp;
  final String qrImageUrl;
  final String fallbackUrl;
  final String? notice;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF101828);
    final bodyColor = isDark ? const Color(0xFFCBD2E1) : const Color(0xFF64748B);
    final surface = isDark
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF211747), Color(0xFF17102F)],
            ),
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            border: Border.all(color: const Color(0x804A347D), width: 1.2),
          )
        : BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDCE4EE), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: DecoratedBox(
        decoration: surface,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay to print',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      detail,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: bodyColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      followUp,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: bodyColor,
                      ),
                    ),
                    if (notice != null && notice!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      KioskStatusBanner(
                        message: notice!,
                        tone: KioskBannerTone.warning,
                        icon: Icons.info_outline,
                      ),
                    ],
                    if (error != null && error!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      KioskStatusBanner(
                        message: error!,
                        tone: KioskBannerTone.danger,
                        icon: Icons.error_outline,
                      ),
                    ],
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Container(
                width: 420,
                height: 420,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _QrFace(
                  qrImageUrl: qrImageUrl,
                  fallbackUrl: fallbackUrl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrFace extends StatelessWidget {
  const _QrFace({required this.qrImageUrl, required this.fallbackUrl});

  final String qrImageUrl;
  final String fallbackUrl;

  @override
  Widget build(BuildContext context) {
    if (qrImageUrl.isNotEmpty) {
      return Image.network(
        qrImageUrl,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.qr_code_2, size: 64)),
      );
    }
    if (fallbackUrl.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return QrImageView(
      data: fallbackUrl,
      version: QrVersions.auto,
      backgroundColor: Colors.white,
    );
  }
}

/// Free-print result after the phone OTP is verified.
Future<void> showKioskPrintQuotaDialog({
  required BuildContext context,
  required String remainingLabel,
  required String costLine,
  String? notice,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      final titleColor = isDark ? Colors.white : const Color(0xFF101828);
      final bodyColor = isDark ? const Color(0xFFCBD2E1) : const Color(0xFF64748B);
      return Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: isDark
                ? BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF211747), Color(0xFF17102F)],
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(24)),
                    border: Border.all(
                      color: const Color(0x804A347D),
                      width: 1.2,
                    ),
                  )
                : BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0x383D6BFF),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x143D6BFF),
                        blurRadius: 18,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Free print check',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    remainingLabel,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    costLine,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: bodyColor,
                    ),
                  ),
                  if (notice != null && notice.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      notice,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: bodyColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: KioskPrimaryButton(
                      label: 'OK',
                      expand: false,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
