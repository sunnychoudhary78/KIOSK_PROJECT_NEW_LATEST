import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/find_services/domain/local_service.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class FindServiceContactsPage extends StatelessWidget {
  const FindServiceContactsPage({super.key, required this.category});

  final LocalServiceCategory category;

  Future<void> _call(BuildContext context, LocalServiceContact contact) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri(scheme: 'tel', path: contact.dialDigits);
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotPlaceCall)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkpPageHeader(
            title: category.name,
            subtitle: l10n.findServicesContactsHelper,
          ),
          const SizedBox(height: 20),
          if (category.contacts.isEmpty)
            Expanded(
              child: SkpEmptyState(
                icon: Icons.phone_disabled_outlined,
                title: l10n.findServicesNoContacts,
                message: l10n.findServicesContactsHelper,
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: category.contacts.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final contact = category.contacts[index];
                  return SkpPanelCard(
                    onTap: () => _call(context, contact),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        SkpIconWell(
                          icon: Icons.person_outline_rounded,
                          size: 48,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contact.displayPhone,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: SkpColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: SkpColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.call_rounded,
                            color: SkpColors.accent,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
