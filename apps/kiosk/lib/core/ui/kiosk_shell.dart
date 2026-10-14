import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/kiosk_buttons.dart';
import 'package:skp_kiosk/core/ui/kiosk_clock.dart';
import 'package:skp_kiosk/core/ui/kiosk_scaffold.dart';
import 'package:skp_kiosk/features/surveillance/presentation/surveillance_status_chip.dart';

/// Persistent ATM chrome: wordmark + clock + Home, optional footer CTAs.
class KioskShell extends StatelessWidget {
  const KioskShell({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.onHome,
    this.showHome = true,
    this.footerLeading,
    this.stepLabel,
    this.footerTrailing,
    this.headerExtra,
    this.cosmic = false,
  });

  final Widget body;
  final String? title;
  final String? subtitle;
  final VoidCallback? onHome;
  final bool showHome;
  final Widget? footerLeading;
  final String? stepLabel;
  final Widget? footerTrailing;
  final Widget? headerExtra;
  final bool cosmic;

  bool get _hasFooter =>
      footerLeading != null || stepLabel != null || footerTrailing != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = cosmic ? SkpColors.gold : SkpColors.accent;
    final muted = cosmic ? const Color(0xFFA8B0BC) : SkpColors.muted;
    final divider = cosmic ? const Color(0x33E8C872) : SkpColors.line;
    final titleColor = cosmic ? const Color(0xFFF4F0E6) : SkpColors.muted;

    Widget chrome = KioskScaffold(
      cosmic: cosmic,
      useAtmosphere: !cosmic,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: SkpTokens.headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'Smart Kiosk',
                    style: theme.textTheme.titleLarge?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: brand,
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(width: 16),
                    Container(
                      width: SkpTokens.hairline,
                      height: 28,
                      color: divider,
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        title!,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: titleColor,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (title != null) const Spacer(),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                  ?headerExtra,
                  if (!cosmic) const SurveillanceStatusChip(),
                  DefaultTextStyle.merge(
                    style: TextStyle(color: cosmic ? const Color(0xFFF4F0E6) : null),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: cosmic ? const Color(0xFFF4F0E6) : null,
                      ),
                      child: const KioskClock(),
                    ),
                  ),
                  if (showHome && onHome != null) ...[
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: onHome,
                        icon: const Icon(Icons.home_outlined, size: 22),
                        label: const Text('Home'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              cosmic ? const Color(0xFFF4F0E6) : null,
                          side: cosmic
                              ? const BorderSide(color: Color(0x55E8C872))
                              : null,
                          minimumSize: const Size(112, 56),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1, color: divider),
          Expanded(child: body),
          if (_hasFooter) ...[
            Divider(height: 1, color: divider),
            SizedBox(
              height: SkpTokens.footerHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: footerLeading ?? const SizedBox.shrink(),
                      ),
                    ),
                    Expanded(
                      child: stepLabel == null
                          ? const SizedBox.shrink()
                          : Text(
                              stepLabel!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: cosmic ? SkpColors.gold : SkpColors.muted,
                                letterSpacing: cosmic ? 1.1 : null,
                                fontWeight: cosmic ? FontWeight.w600 : null,
                              ),
                            ),
                    ),
                    SizedBox(
                      width: 280,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: footerTrailing == null
                            ? const SizedBox.shrink()
                            : ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 180,
                                  maxWidth: 280,
                                ),
                                child: footerTrailing,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!cosmic) {
      return chrome;
    }

    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          outline: const Color(0x55E8C872),
          onSurface: const Color(0xFFF4F0E6),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF4F0E6),
            side: const BorderSide(color: Color(0x55E8C872)),
          ),
        ),
        dividerColor: divider,
      ),
      child: chrome,
    );
  }
}

class KioskHomeAction extends StatelessWidget {
  const KioskHomeAction({super.key, required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return KioskGhostButton(label: label, onPressed: onPressed, icon: Icons.arrow_back);
  }
}
