import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/local_services/domain/local_service.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class LocalServiceContactsPage extends ConsumerWidget {
  const LocalServiceContactsPage({super.key, required this.category});

  final LocalServiceCategory category;

  Future<void> _endSession(WidgetRef ref) {
    return ref.read(kioskSessionControllerProvider.notifier).endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.athenaColors;
    final token = ref.watch(deviceAuthProvider.select((s) => s.accessToken));

    return VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: category.name,
        onHome: () => _endSession(ref),
        footerLeading: KioskGhostButton(
          label: 'Back',
          icon: Icons.arrow_back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Providers near you',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pinned first · highest rating next',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: category.contacts.isEmpty
                    ? Center(
                        child: Text(
                          'No numbers in this list.',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: category.contacts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact, required this.accessToken});

  final LocalServiceContact contact;
  final String? accessToken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.athenaColors;
    final isDark = theme.brightness == Brightness.dark;
    final address = contact.address?.trim();
    final photoUrl = _absolutePhotoUrl(contact.photoUrl);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF211747), Color(0xFF17102F)],
              )
            : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: contact.pinned
              ? const Color(0xFFF59E0B)
              : (isDark ? const Color(0xFF7445BD) : const Color(0xFFE2EBF5)),
          width: contact.pinned ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x2E8B35FF) : const Color(0x0C1B2B4F),
            blurRadius: isDark ? 16 : 10,
            offset: isDark ? Offset.zero : const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _PhotoAvatar(
              name: contact.name,
              photoUrl: photoUrl,
              accessToken: accessToken,
              accent: colors.accentMagenta,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (contact.pinned) ...[
                        Icon(
                          Icons.push_pin_rounded,
                          size: 16,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          contact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
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
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _formatPhone(contact.phone),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: colors.accentMagenta,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    required this.accent,
  });

  final String name;
  final String? photoUrl;
  final String? accessToken;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    final placeholder = Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
    );

    if (photoUrl == null || accessToken == null || accessToken!.isEmpty) {
      return placeholder;
    }

    return ClipOval(
      child: Image.network(
        photoUrl!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        headers: {'Authorization': 'Bearer $accessToken'},
        errorBuilder: (_, __, ___) => placeholder,
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

String? _absolutePhotoUrl(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;
  if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
    return photoUrl;
  }
  final base = AppConfig.fromEnvironment().apiBaseUrl;
  if (photoUrl.startsWith('/v1/') &&
      (base.endsWith('/v1') || base.endsWith('/v1/'))) {
    return '$base${photoUrl.substring(3)}';
  }
  if (photoUrl.startsWith('/')) return '$base$photoUrl';
  return '$base/$photoUrl';
}

String _formatPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) {
    final head = digits.substring(0, 5);
    final tail = digits.substring(5);
    return '+91 $head $tail';
  }
  if (digits.length == 12 && digits.startsWith('91')) {
    final head = digits.substring(2, 7);
    final tail = digits.substring(7);
    return '+91 $head $tail';
  }
  return phone;
}
