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
    final contacts = category.contacts;

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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nearby providers',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: contacts.isEmpty
                    ? Center(
                        child: Text(
                          'No providers near this kiosk yet. Add lat/lng in Admin.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: contacts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _ContactCard(
                            contact: contacts[index],
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
  const _ContactCard({
    required this.contact,
    required this.accessToken,
  });

  final LocalServiceContact contact;
  final String? accessToken;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final address = contact.address?.trim();
    final photoUrl = _absolutePhotoUrl(contact.photoUrl);

    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C143F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF7445BD) : const Color(0xFFD7E3F2),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1B2B4F),
            blurRadius: 14,
            offset: Offset(0, 4),
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (contact.topRank != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Text(
                            'Top ${contact.topRank}',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (contact.distanceKm != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.near_me_rounded,
                          size: 16,
                          color: Color(0xFF0369A1),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(contact.distanceKm!),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (address != null && address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatPhone(contact.phone),
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: colors.accentMagenta,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _RatingBlock(rating: contact.rating),
          ],
        ),
      ),
    );
  }
}

class _RatingBlock extends StatelessWidget {
  const _RatingBlock({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final label = rating == rating.roundToDouble()
        ? rating.toStringAsFixed(0)
        : rating.toStringAsFixed(1);

    return Container(
      width: 118,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, size: 22, color: Color(0xFFF59E0B)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Color(0xFF9A3412),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _StarRow(rating: rating),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final IconData icon;
        if (rating >= starValue) {
          icon = Icons.star_rounded;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: 14, color: const Color(0xFFF59E0B));
      }),
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
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 2),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 28,
          fontWeight: FontWeight.w900,
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
        width: 72,
        height: 72,
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

String _formatDistance(double km) {
  if (km <= 0.05) {
    return 'At this kiosk';
  }
  if (km < 1) {
    final meters = (km * 1000).round();
    return '$meters m away';
  }
  final label = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
  return '$label km away';
}
