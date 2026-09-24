import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = [
      (l10n.howItWorksStep1Title, l10n.howItWorksStep1Body, Icons.upload_file_rounded),
      (l10n.howItWorksStep2Title, l10n.howItWorksStep2Body, Icons.sms_outlined),
      (l10n.howItWorksStep3Title, l10n.howItWorksStep3Body, Icons.print_outlined),
    ];

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: ListView(
        children: [
          SkpPageHeader(
            title: l10n.howItWorksTitle,
            subtitle: l10n.howItWorksIntro,
            showBack: true,
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < steps.length; i++) ...[
            SkpPanelCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkpIconWell(icon: steps[i].$3),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${steps[i].$1}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          steps[i].$2,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: SkpColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
