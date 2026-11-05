import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

/// Full-body print-in-progress panel (same layout language as [KioskPrintResult]).
class KioskPrintingProgress extends StatelessWidget {
  const KioskPrintingProgress({
    super.key,
    this.title = 'Printing…',
    this.detail,
  });

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawDetail = detail?.trim();
    final showDetail = rawDetail != null &&
        rawDetail.isNotEmpty &&
        rawDetail != title &&
        rawDetail != 'Printing…';

    return Padding(
      padding: SkpTokens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                color: SkpColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          if (showDetail) ...[
            const SizedBox(height: 12),
            Text(
              rawDetail,
              style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}
