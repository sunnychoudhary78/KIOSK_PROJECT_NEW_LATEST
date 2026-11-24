import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/find_services/domain/local_service.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class FindServiceContactsPage extends StatelessWidget {
  const FindServiceContactsPage({super.key, required this.category});

  final LocalServiceCategory category;

  @override
  Widget build(BuildContext context) {
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
                  return _ContactRevealCard(contact: category.contacts[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactRevealCard extends StatefulWidget {
  const _ContactRevealCard({required this.contact});

  final LocalServiceContact contact;

  @override
  State<_ContactRevealCard> createState() => _ContactRevealCardState();
}

class _ContactRevealCardState extends State<_ContactRevealCard> {
  bool _revealed = false;

  Future<void> _call() async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri(scheme: 'tel', path: widget.contact.dialDigits);
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotPlaceCall)),
      );
    }
  }

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
  }

  void _collapse() {
    if (!_revealed) return;
    setState(() => _revealed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SkpPanelCard(
      onTap: _revealed ? null : _reveal,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SkpIconWell(
                icon: Icons.person_outline_rounded,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.contact.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!_revealed)
                TextButton(
                  onPressed: _reveal,
                  child: Text(l10n.findServicesMoreInfo),
                )
              else
                IconButton(
                  onPressed: _collapse,
                  tooltip: l10n.findServicesMoreInfo,
                  icon: const Icon(
                    Icons.expand_less_rounded,
                    color: SkpColors.muted,
                  ),
                ),
            ],
          ),
          if (_revealed) ...[
            const SizedBox(height: 14),
            Text(
              widget.contact.displayPhone,
              style: theme.textTheme.titleMedium?.copyWith(
                color: SkpColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.findServicesContactHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: SkpColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            SkpPrimaryButton(
              label: l10n.findServicesCall,
              onPressed: _call,
            ),
          ],
        ],
      ),
    );
  }
}
