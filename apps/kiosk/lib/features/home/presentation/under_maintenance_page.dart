import 'package:flutter/material.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';

/// Shared screen when a home service is disabled for this kiosk.
class UnderMaintenancePage extends StatelessWidget {
  const UnderMaintenancePage({
    super.key,
    this.serviceTitle,
  });

  final String? serviceTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = serviceTitle == null || serviceTitle!.isEmpty
        ? 'This service is temporarily unavailable on this kiosk.'
        : '$serviceTitle is temporarily unavailable on this kiosk.';

    return KioskShell(
      title: 'Under maintenance',
      onHome: () => Navigator.of(context).popUntil(
        (route) => route.isFirst || route.settings.name == AppRoutes.home,
      ),
      body: Padding(
        padding: SkpTokens.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_rounded, size: 88, color: SkpColors.gold),
            const SizedBox(height: 24),
            Text(
              'Under maintenance',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
