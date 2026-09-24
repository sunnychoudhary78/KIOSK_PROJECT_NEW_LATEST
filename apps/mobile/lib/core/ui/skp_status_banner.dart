import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';

enum SkpBannerTone { info, success, warning, danger }

class SkpStatusBanner extends StatelessWidget {
  const SkpStatusBanner({
    super.key,
    required this.message,
    this.detail,
    this.tone = SkpBannerTone.info,
    this.icon,
  });

  final String message;
  final String? detail;
  final SkpBannerTone tone;
  final IconData? icon;

  Color get _color => switch (tone) {
        SkpBannerTone.info => SkpColors.accent,
        SkpBannerTone.success => SkpColors.success,
        SkpBannerTone.warning => const Color(0xFF8A6A12),
        SkpBannerTone.danger => SkpColors.danger,
      };

  IconData get _icon => icon ?? switch (tone) {
        SkpBannerTone.info => Icons.info_outline_rounded,
        SkpBannerTone.success => Icons.check_circle_outline_rounded,
        SkpBannerTone.warning => Icons.schedule_rounded,
        SkpBannerTone.danger => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        border: Border.all(color: _color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: theme.textTheme.titleSmall?.copyWith(color: _color),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
