import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_paid_print.dart';

Future<void> showAstrologyPrintQuotaDialog({
  required BuildContext context,
  required AstrologyPrintQuota summary,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Free print check'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.remainingLabel,
              style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              summary.printCostLine,
              style: Theme.of(dialogContext).textTheme.bodyLarge,
            ),
            if (summary.message != null &&
                summary.message!.trim().isNotEmpty &&
                !summary.freeEligible) ...[
              const SizedBox(height: 12),
              Text(
                summary.message!,
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
        actions: [
          KioskPrimaryButton(
            label: 'OK',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}
