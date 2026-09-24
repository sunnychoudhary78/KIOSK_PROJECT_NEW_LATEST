import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/format.dart';
import 'package:skp_mobile/core/l10n/app_locale.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(citizenAuthProvider);
    final locale = ref.watch(appLocaleProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final phone = maskPhone(auth.phone);

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkpPageHeader(
            title: l10n.profileTitle,
            showBack: !embedded,
          ),
          const SizedBox(height: 24),
          SkpPanelCard(
            child: Row(
              children: [
                const SkpIconWell(icon: Icons.person_rounded, size: 56, iconSize: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.citizenAccount,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone.isEmpty ? l10n.citizenAccount : phone,
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
          const SizedBox(height: 16),
          SkpPanelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.language_rounded,
                  title: l10n.language,
                  value: locale.languageCode == 'hi'
                      ? l10n.languageHindi
                      : l10n.languageEnglish,
                  onTap: () => _chooseLanguage(context, ref),
                ),
                const Divider(height: 1),
                _SettingsRow(
                  icon: Icons.help_outline_rounded,
                  title: l10n.howItWorks,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.howItWorks),
                ),
                const Divider(height: 1),
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: l10n.about,
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.about),
                ),
              ],
            ),
          ),
          const Spacer(),
          SkpSecondaryButton(
            label: l10n.signOut,
            onPressed: () {
              ref.read(citizenAuthProvider.notifier).logout();
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.chooseLanguage,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.languageEnglish),
                  onTap: () => Navigator.pop(context, const Locale('en')),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.languageHindi),
                  onTap: () => Navigator.pop(context, const Locale('hi')),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      await ref.read(appLocaleProvider.notifier).setLocale(selected);
    }
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: SkpColors.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: SkpColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: SkpColors.muted),
          ],
        ),
      ),
    );
  }
}
