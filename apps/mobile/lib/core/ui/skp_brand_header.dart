import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';

class SkpBrandHeader extends StatelessWidget {
  const SkpBrandHeader({
    super.key,
    this.subtitle,
    this.compact = false,
    this.centered = true,
  });

  final String? subtitle;
  final bool compact;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = centered ? TextAlign.center : TextAlign.start;
    final cross = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(
          'Smart Kiosk',
          textAlign: align,
          style: (compact ? theme.textTheme.headlineSmall : theme.textTheme.displaySmall)
              ?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            color: SkpColors.ink,
            height: 1.05,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: compact ? 8 : 14),
          Text(
            subtitle!,
            textAlign: align,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: SkpColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}
