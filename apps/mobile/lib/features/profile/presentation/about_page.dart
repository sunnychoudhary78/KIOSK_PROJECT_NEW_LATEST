import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkpPageHeader(title: l10n.aboutTitle, showBack: true),
          const SizedBox(height: 24),
          SkpPanelCard(
            child: Text(
              l10n.aboutBody,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SkpColors.ink,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
