import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

enum KioskServiceTileTone { standard, cosmic }

class KioskServiceTile extends StatelessWidget {
  const KioskServiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone = KioskServiceTileTone.standard,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final KioskServiceTileTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cosmic = tone == KioskServiceTileTone.cosmic;
    final titleColor = cosmic ? const Color(0xFFF4F0E6) : SkpColors.text;
    final subtitleColor = cosmic ? const Color(0xFFA8B0BC) : SkpColors.muted;
    final iconColor = cosmic ? SkpColors.gold : SkpColors.accent;
    final chipBg = cosmic
        ? SkpColors.gold.withValues(alpha: 0.16)
        : SkpColors.accent.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
            gradient: cosmic
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0B1220),
                      Color(0xFF1A2440),
                      Color(0xFF152238),
                    ],
                  )
                : null,
            color: cosmic ? null : SkpColors.panel,
            border: Border.all(
              color: cosmic ? SkpColors.gold.withValues(alpha: 0.45) : SkpColors.line,
              width: SkpTokens.hairline,
            ),
            boxShadow: [
              BoxShadow(
                color: cosmic
                    ? SkpColors.gold.withValues(alpha: 0.12)
                    : SkpColors.text.withValues(alpha: 0.04),
                blurRadius: cosmic ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: SkpTokens.tileMinWidth,
              minHeight: SkpTokens.tileMinHeight,
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(18),
                          border: cosmic
                              ? Border.all(
                                  color: SkpColors.gold.withValues(alpha: 0.4),
                                )
                              : null,
                        ),
                        child: Icon(icon, size: 36, color: iconColor),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: subtitleColor,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
