import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/kiosk_buttons.dart';
import 'package:skp_kiosk/core/ui/kiosk_clock.dart';
import 'package:skp_kiosk/core/ui/kiosk_scaffold.dart';

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

  bool get _hasFooter =>
      footerLeading != null || stepLabel != null || footerTrailing != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KioskScaffold(
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
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: SkpColors.text,
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(width: 16),
                    Container(
                      width: SkpTokens.hairline,
                      height: 28,
                      color: SkpColors.line,
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        title!,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: SkpColors.muted,
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
                          color: SkpColors.muted,
                        ),
                      ),
                    ),
                  ?headerExtra,
                  const KioskClock(),
                  if (showHome && onHome != null) ...[
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: onHome,
                        icon: const Icon(Icons.home_outlined, size: 22),
                        label: const Text('Home'),
                        style: OutlinedButton.styleFrom(
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
          const Divider(height: 1),
          Expanded(child: body),
          if (_hasFooter) ...[
            const Divider(height: 1),
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
                                color: SkpColors.muted,
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
