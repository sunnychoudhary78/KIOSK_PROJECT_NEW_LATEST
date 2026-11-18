import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';

/// Full-screen state when an admin has stopped this kiosk.
class StoppedKioskPage extends StatelessWidget {
  const StoppedKioskPage({
    super.key,
    this.deviceName,
  });

  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = deviceName?.trim();
    final hasName = name != null && name.isNotEmpty;

    return KioskShell(
      title: 'Out of service',
      showHome: false,
      body: Padding(
        padding: SkpTokens.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.power_settings_new_rounded,
              size: 88,
              color: SkpColors.danger,
            ),
            const SizedBox(height: 24),
            Text(
              'This kiosk is stopped',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Services are unavailable right now. It will return automatically when an operator starts it again.',
              style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.muted),
              textAlign: TextAlign.center,
            ),
            if (hasName) ...[
              const SizedBox(height: 12),
              Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
