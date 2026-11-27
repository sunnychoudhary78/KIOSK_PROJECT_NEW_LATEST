import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/core/config/app_config.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/find_services/domain/local_service.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class FindServiceContactsPage extends ConsumerWidget {
  const FindServiceContactsPage({super.key, required this.category});

  final LocalServiceCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final token = ref.watch(citizenAuthProvider.select((s) => s.token));

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
                  return _ContactCard(
                    contact: category.contacts[index],
                    accessToken: token,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatefulWidget {
  const _ContactCard({required this.contact, required this.accessToken});

  final LocalServiceContact contact;
  final String? accessToken;

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  bool _revealed = false;

  LocalServiceContact get contact => widget.contact;

  Future<void> _call() async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri(scheme: 'tel', path: contact.dialDigits);
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
    final address = contact.address?.trim();
    final photoUrl = _absolutePhotoUrl(contact.photoUrl);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
      side: BorderSide(
        color: contact.topRank != null ? const Color(0xFFF59E0B) : SkpColors.line,
        width: contact.topRank != null ? 1.6 : 1,
      ),
    );

    return Material(
      color: SkpColors.panel,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _revealed ? null : _reveal,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PhotoAvatar(
                    name: contact.name,
                    photoUrl: photoUrl,
                    accessToken: widget.accessToken,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (contact.topRank != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFFCD34D)),
                                ),
                                child: Text(
                                  'Top ${contact.topRank}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                contact.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _RatingBadge(rating: contact.rating),
                          ],
                        ),
                        if (address != null && address.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: SkpColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: SkpColors.muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (contact.distanceKm != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.near_me_outlined,
                                size: 15,
                                color: SkpColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDistance(contact.distanceKm!),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: SkpColors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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
                  contact.displayPhone,
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
        ),
      ),
    );
  }
}

class _PhotoAvatar extends StatelessWidget {
  const _PhotoAvatar({
    required this.name,
    required this.photoUrl,
    required this.accessToken,
  });

  final String name;
  final String? photoUrl;
  final String? accessToken;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    final placeholder = Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SkpColors.accent.withValues(alpha: 0.12),
        border: Border.all(color: SkpColors.accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: SkpColors.accent,
        ),
      ),
    );

    if (photoUrl == null || accessToken == null || accessToken!.isEmpty) {
      return placeholder;
    }

    return ClipOval(
      child: Image.network(
        photoUrl!,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        headers: {'Authorization': 'Bearer $accessToken'},
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder;
        },
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final label = rating == rating.roundToDouble()
        ? rating.toStringAsFixed(0)
        : rating.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Color(0xFF9A3412),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDistance(double km) {
  if (km < 1) {
    return '${(km * 1000).round()} m';
  }
  if (km < 10) {
    return '${km.toStringAsFixed(1)} km';
  }
  return '${km.toStringAsFixed(0)} km';
}

String? _absolutePhotoUrl(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;
  if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
    return photoUrl;
  }
  final base = AppConfig.current.apiBaseUrl;
  if (photoUrl.startsWith('/v1/') &&
      (base.endsWith('/v1') || base.endsWith('/v1/'))) {
    return '$base${photoUrl.substring(3)}';
  }
  if (photoUrl.startsWith('/')) return '$base$photoUrl';
  return '$base/$photoUrl';
}
