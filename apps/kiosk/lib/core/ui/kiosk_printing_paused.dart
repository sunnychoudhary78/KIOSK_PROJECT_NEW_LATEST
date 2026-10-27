import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/features/printer/application/printer_health_controller.dart';

bool kioskPrintingPaused(WidgetRef ref) {
  final reason = ref.watch(deviceAuthProvider).printingPausedReason;
  final health = ref.watch(printerHealthControllerProvider);
  return reason == 'paper_out' || health.state == 'paper_out' || health.noPaper;
}

class KioskPrintingPaused extends StatelessWidget {
  const KioskPrintingPaused({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: SkpTokens.pagePadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 88, color: SkpColors.gold),
          const SizedBox(height: 24),
          Text(
            'Out of paper',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Printing is paused.',
            style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
