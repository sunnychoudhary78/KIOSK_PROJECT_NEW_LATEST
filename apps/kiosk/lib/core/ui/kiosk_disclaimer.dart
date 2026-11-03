import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

/// Explicit privacy copy shown on sensitive kiosk flows.
abstract final class KioskDisclaimerCopy {
  static const printDocuments =
      'We do not save your documents. Files are used only to print this session, then removed from this kiosk.';

  static const digilocker =
      'We do not save DigiLocker documents or login data. Access is for this print session only; nothing is stored after you leave.';

  static const otpPrint =
      'We do not save your documents or OTP. Content is fetched only to print now, then cleared.';

  static const qrPrint =
      'We do not save uploaded documents. Your phone upload is for this print session only, then deleted from the kiosk.';

  static const wellBeing =
      'We do not save health readings. Measurements stay on this screen only and are cleared when you leave.';

  static const astrology =
      'We do not save birth details or palm photos. Data is used only for this reading, then cleared when you leave.';
}

/// Persistent privacy notice — same chrome language as [KioskStatusBanner].
class KioskDisclaimer extends StatelessWidget {
  const KioskDisclaimer({
    super.key,
    required this.message,
    this.icon = Icons.verified_user_outlined,
    this.compact = false,
  });

  final String message;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = SkpColors.accentBright;
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 14);
    final iconSize = compact ? 22.0 : 26.0;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: iconSize),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: (compact ? theme.textTheme.bodyMedium : theme.textTheme.titleMedium)
                  ?.copyWith(
                color: color,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
