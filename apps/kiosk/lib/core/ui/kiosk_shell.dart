import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/kiosk_buttons.dart';
import 'package:skp_kiosk/core/ui/kiosk_clock.dart';
import 'package:skp_kiosk/core/ui/kiosk_scaffold.dart';
import 'package:skp_kiosk/core/ui/theme_mode_toggle_pill.dart';
import 'package:skp_kiosk/features/surveillance/presentation/surveillance_status_chip.dart';

/// Persistent shell chrome: brand lockup | section title | clock + home.
/// Exactly matches reference images 2, 3, 4, 5.
class KioskShell extends StatelessWidget {
  const KioskShell({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.onHome,
    this.showHome = true,
    this.footerLeading,
    this.stepLabel,
    this.footerCenter,
    this.footerTrailing,
    this.headerExtra,
    this.showLogo = false,
    this.cosmic = false,
    this.titleIcon,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final VoidCallback? onHome;
  final bool showHome;
  final Widget? footerLeading;
  final String? stepLabel;
  final Widget? footerCenter;
  final Widget? footerTrailing;
  final Widget? headerExtra;
  final bool showLogo;
  final bool cosmic;
  final IconData? titleIcon;

  bool get _hasFooter =>
      footerLeading != null || stepLabel != null || footerTrailing != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divider = isDark
        ? const Color(0xFF2E1C59)
        : const Color(0xFFE2EBF5);

    return KioskScaffold(
      cosmic: cosmic,
      useAtmosphere: !cosmic,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Bar ─────────────────────────────────────────
          Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Athena Logo
                Image.asset(
                  'assets/brand/athena_logo.png',
                  height: 42,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _AthenaFallbackLogo(colors: colors),
                ),

                // Section divider + title
                if (titleWidget != null) ...[
                  const SizedBox(width: 16),
                  titleWidget!,
                ] else if (title != null) ...[
                  const SizedBox(width: 16),
                  Container(width: 1, height: 22, color: divider),
                  const SizedBox(width: 16),
                  if (titleIcon != null) ...[
                    Icon(titleIcon, size: 20, color: colors.accentMagenta),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      title!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // Right action cluster: headerExtra, surveillance, theme mode, clock, home
                Flexible(
                  flex: 3,
                  fit: FlexFit.loose,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Extra widget (e.g. weather strip) - scales down if constrained
                      if (headerExtra != null) ...[
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: headerExtra!,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Surveillance chip
                      if (!cosmic) ...[
                        const SurveillanceStatusChip(),
                        const SizedBox(width: 8),
                      ],

                      // Theme mode toggle (commented out for now; uncomment if toggle is needed later)
                      // const ThemeModeTogglePill(),
                      // const SizedBox(width: 8),

                      // Clock capsule
                      const KioskClock(capsule: true),

                      // Home button
                      if (showHome && onHome != null) ...[
                        const SizedBox(width: 8),
                        _TopBarPill(
                          onTap: onHome!,
                          colors: colors,
                          isDark: isDark,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.home_outlined, size: 17, color: colors.textPrimary),
                              const SizedBox(width: 6),
                              Text(
                                'Home',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Header Divider
          Container(height: 1, color: divider),

          // Body
          Expanded(child: body),

          // ── Footer ──────────────────────────────────────────
          if (_hasFooter) ...[
            Container(height: 1, color: divider),
            SizedBox(
              height: 72,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  children: [
                    if (footerLeading != null) footerLeading!,
                    if (footerCenter != null) ...[
                      const Spacer(),
                      footerCenter!,
                      const Spacer(),
                    ] else if (stepLabel != null) ...[
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 1.5,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              stepLabel!,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          Container(
                            width: 24,
                            height: 1.5,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    if (footerTrailing != null) footerTrailing!,
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Simple pill button for top bar (Clock, Home)
class _TopBarPill extends StatelessWidget {
  const _TopBarPill({
    required this.onTap,
    required this.colors,
    required this.isDark,
    required this.child,
  });

  final VoidCallback onTap;
  final AthenaColors colors;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C143F) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF7445BD) : const Color(0xFFD8E4F2),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x2E8B35FF)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _AthenaFallbackLogo extends StatelessWidget {
  const _AthenaFallbackLogo({required this.colors});

  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.accentMagenta, width: 2),
          ),
          child: Center(
            child: Text(
              'A',
              style: TextStyle(
                color: colors.accentMagenta,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ATHENA',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 1.0,
                color: colors.textPrimary,
              ),
            ),
            Text(
              'Your Smart Everyday Assistant',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
