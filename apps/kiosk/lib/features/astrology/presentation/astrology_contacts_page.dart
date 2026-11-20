import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_contacts_controller.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_contact.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/reading_mark.dart';
import 'package:skp_kiosk/features/service_analytics/application/service_analytics_tracker.dart';
import 'package:skp_kiosk/features/service_analytics/domain/service_event_keys.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

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
      ref.read(astrologyContactsControllerProvider.notifier).load(widget.kind);
    });
  }

  Future<void> _endSession() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  String get _title =>
      widget.kind == AstrologyContactKind.astrologer
          ? 'Contact Astrologer'
          : 'Contact Pandit';

  AstrologyReadingKind get _readingKind =>
      widget.kind == AstrologyContactKind.astrologer
          ? AstrologyReadingKind.astrologer
          : AstrologyReadingKind.pandit;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(astrologyContactsControllerProvider);
    final accent = _readingKind.accent;

    return VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: _title,
        onHome: _endSession,
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
                'Name & rating',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap Show number to reveal the phone',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: state.loading && state.contacts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.contacts.isEmpty
                        ? _EmptyContactsState(
                            accent: accent,
                            isDark: isDark,
                          )
                        : ListView.separated(
                            itemCount: state.contacts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _ContactCard(
                                contact: state.contacts[index],
                                accent: accent,
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

class _EmptyContactsState extends StatelessWidget {
  const _EmptyContactsState({
    required this.accent,
    required this.isDark,
  });

  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1738) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.45 : 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hourglass_empty_rounded,
                  size: 42,
                  color: accent,
                ),
                const SizedBox(height: 14),
                Text(
                  'Coming soon',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends ConsumerStatefulWidget {
  const _ContactCard({
    required this.contact,
    required this.accent,
  });

  final AstrologyContact contact;
  final Color accent;

  @override
  ConsumerState<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends ConsumerState<_ContactCard> {
  bool _revealed = false;
  bool _revealing = false;

  Future<void> _reveal() async {
    if (_revealed || _revealing) {
      return;
    }
    setState(() => _revealing = true);
    try {
      await ref
          .read(astrologyContactsRepositoryProvider)
          .reveal(widget.contact.id);
      final eventKey = widget.contact.kind == AstrologyContactKind.astrologer
          ? ServiceEventKeys.astrologyAstrologerShowNumber
          : ServiceEventKeys.astrologyPanditShowNumber;
      // ignore: discarded_futures
      ref.read(serviceAnalyticsTrackerProvider).track(
            eventKey,
            metadata: {
              'contactId': widget.contact.id,
              'name': widget.contact.name,
            },
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _revealed = true;
        _revealing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      // Still reveal locally so the visitor is not blocked by a network blip.
      setState(() {
        _revealed = true;
        _revealing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.athenaColors;
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accent;

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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF7445BD) : const Color(0xFFE2EBF5),
          width: 1.0,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contact.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StarRating(rating: widget.contact.rating, accent: accent),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (_revealed)
              Text(
                _formatPhone(widget.contact.phone),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: accent,
                ),
              )
            else
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _revealing ? null : () => _reveal(),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.7),
                        width: 1.4,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_revealing)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            )
                          else
                            Icon(
                              Icons.phone_rounded,
                              size: 18,
                              color: accent,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _revealing ? 'Opening…' : 'Show number',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.accent});

  final double rating;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final empty = isDark ? const Color(0xFF4B5563) : const Color(0xFFCBD5E1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i > 1) const SizedBox(width: 2),
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: 22,
            color: rating >= i - 0.5 ? accent : empty,
          ),
        ],
        const SizedBox(width: 8),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
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
