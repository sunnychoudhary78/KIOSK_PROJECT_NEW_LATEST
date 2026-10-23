import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/config/app_config.dart';
import 'package:skp_mobile/core/format.dart';
import 'package:skp_mobile/core/l10n/app_locale.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

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
          Expanded(
            child: ListView(
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
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.privacy_tip_outlined,
                        title: l10n.privacyPolicy,
                        onTap: () => _openPrivacyPolicy(context),
                      ),
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.delete_outline_rounded,
                        title: l10n.deleteAccount,
                        iconColor: SkpColors.danger,
                        titleColor: SkpColors.danger,
                        onTap: () => _confirmDeleteAccount(context, ref),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.parse(AppConfig.current.privacyPolicyUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotOpenPrivacyPolicy)),
      );
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteAccountTitle),
          content: Text(l10n.deleteAccountBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                l10n.deleteAccountConfirm,
                style: const TextStyle(color: SkpColors.danger),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final deleted = await ref.read(citizenAuthProvider.notifier).deleteAccount();
    if (!context.mounted) return;
    if (deleted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
      );
      return;
    }
    final message = ref.read(citizenAuthProvider).error ?? l10n.deleteAccountFailed;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? SkpColors.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: titleColor,
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
