import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/astrology_contacts/application/astrology_contacts_controller.dart';
import 'package:skp_mobile/features/astrology_contacts/domain/astrology_contact.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class AstrologyContactsPage extends ConsumerStatefulWidget {
  const AstrologyContactsPage({super.key, required this.kind});

  final AstrologyContactKind kind;

  @override
  ConsumerState<AstrologyContactsPage> createState() =>
      _AstrologyContactsPageState();
}

class _AstrologyContactsPageState extends ConsumerState<AstrologyContactsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(astrologyContactsProvider.notifier).load(widget.kind);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(astrologyContactsProvider);
    final l10n = AppLocalizations.of(context);
    final isPandit = widget.kind == AstrologyContactKind.pandit;
    final title =
        isPandit ? l10n.astrologyPanditTitle : l10n.astrologyAstrologerTitle;
    final helper = isPandit
        ? l10n.astrologyPanditHelper
        : l10n.astrologyAstrologerHelper;

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkpPageHeader(title: title, subtitle: helper),
          const SizedBox(height: 20),
          if (state.loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null)
            Expanded(
              child: SkpEmptyState(
                icon: Icons.auto_awesome_outlined,
                title: state.error!,
                message: helper,
                actionLabel: l10n.retry,
                onAction: () => ref
                    .read(astrologyContactsProvider.notifier)
                    .load(widget.kind),
              ),
            )
          else if (state.contacts.isEmpty)
            Expanded(
              child: SkpEmptyState(
                icon: Icons.auto_awesome_outlined,
                title: l10n.astrologyContactsEmpty,
                message: helper,
                actionLabel: l10n.refresh,
                secondary: true,
                onAction: () => ref
                    .read(astrologyContactsProvider.notifier)
                    .load(widget.kind),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref
                    .read(astrologyContactsProvider.notifier)
                    .load(widget.kind),
                child: ListView.separated(
                  itemCount: state.contacts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _AstrologyContactCard(
                      contact: state.contacts[index],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AstrologyContactCard extends StatefulWidget {
  const _AstrologyContactCard({required this.contact});

  final AstrologyContact contact;

  @override
  State<_AstrologyContactCard> createState() => _AstrologyContactCardState();
}

class _AstrologyContactCardState extends State<_AstrologyContactCard> {
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
    final rating = widget.contact.rating.clamp(0, 5);

    return SkpPanelCard(
      onTap: _revealed ? null : _reveal,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SkpIconWell(
                icon: Icons.auto_awesome_outlined,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.contact.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            i <= rating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18,
                            color: SkpColors.gold,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          rating.toStringAsFixed(
                            rating == rating.roundToDouble() ? 0 : 1,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: SkpColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_revealed)
                TextButton(
                  onPressed: _reveal,
                  child: Text(l10n.astrologyShowNumber),
                )
              else
                IconButton(
                  onPressed: _collapse,
                  tooltip: l10n.astrologyShowNumber,
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
              l10n.astrologyContactHint,
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
