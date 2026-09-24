import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

enum KioskBannerTone { info, success, warning, danger }

class KioskStatusBanner extends StatelessWidget {
  const KioskStatusBanner({
    super.key,
    required this.message,
    this.detail,
    this.tone = KioskBannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? detail;
  final KioskBannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  Color get _color => switch (tone) {
        KioskBannerTone.info => SkpColors.accentBright,
        KioskBannerTone.success => SkpColors.accentBright,
        KioskBannerTone.warning => SkpColors.gold,
        KioskBannerTone.danger => SkpColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon ?? Icons.info_outline, color: _color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: theme.textTheme.titleMedium?.copyWith(color: _color),
                ),
                if (detail != null && detail!.isNotEmpty)
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class KioskLoading extends StatelessWidget {
  const KioskLoading({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class KioskEmpty extends StatelessWidget {
  const KioskEmpty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: SkpColors.muted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: SkpColors.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class KioskDocCard extends StatelessWidget {
  const KioskDocCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.onAction,
    this.leadingIcon = Icons.picture_as_pdf_outlined,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: SkpColors.panel,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        border: Border.all(color: SkpColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: SkpColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(leadingIcon, color: SkpColors.accentBright),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: SkpColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: SkpTokens.tapMin,
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, SkpTokens.tapMin),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class KioskTextTapField extends StatelessWidget {
  const KioskTextTapField({
    super.key,
    required this.label,
    required this.value,
    required this.focused,
    required this.onTap,
    this.obscure = false,
    this.hint,
  });

  final String label;
  final String value;
  final bool focused;
  final VoidCallback onTap;
  final bool obscure;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = obscure && value.isNotEmpty ? '•' * value.length : value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: SkpTokens.tapMin),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: SkpColors.raised,
          borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
          border: Border.all(
            color: focused ? SkpColors.accentBright : SkpColors.line,
            width: focused ? 2 : SkpTokens.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: focused ? SkpColors.accentBright : SkpColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              display.isEmpty ? (hint ?? '') : display,
              style: theme.textTheme.titleLarge?.copyWith(
                color: display.isEmpty ? SkpColors.muted : SkpColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
