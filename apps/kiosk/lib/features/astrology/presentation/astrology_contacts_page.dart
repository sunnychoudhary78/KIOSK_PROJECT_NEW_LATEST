import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
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

  String get _title => switch (widget.kind) {
        AstrologyContactKind.astrologer => 'Contact Astrologer',
        AstrologyContactKind.pandit => 'Contact Pandit',
        AstrologyContactKind.numerology => 'Contact Numerology',
      };

  String get _headline => switch (widget.kind) {
        AstrologyContactKind.astrologer => 'Trusted astrologers',
        AstrologyContactKind.pandit => 'Trusted pandits',
        AstrologyContactKind.numerology => 'Mystic Numerology',
      };

  String get _roleLabel => switch (widget.kind) {
        AstrologyContactKind.astrologer => 'Astrologer',
        AstrologyContactKind.pandit => 'Pandit',
        AstrologyContactKind.numerology => 'Numerologist',
      };

  String get _subtitle => switch (widget.kind) {
        AstrologyContactKind.astrologer =>
          'Experienced guides ready to help — tap to reveal their number',
        AstrologyContactKind.pandit =>
          'Verified pandits for puja & rituals — tap to reveal their number',
        AstrologyContactKind.numerology =>
          'Name & number insights — tap to reveal their phone',
      };

  String get _headerAsset => switch (widget.kind) {
        AstrologyContactKind.numerology =>
          'assets/new_theme_icons/astrology/contact_numerology.png',
        AstrologyContactKind.astrologer =>
          'assets/new_theme_icons/astrology/contact_astrologer.png',
        AstrologyContactKind.pandit =>
          'assets/new_theme_icons/astrology/contact_pandit.png',
      };

  AstrologyReadingKind get _readingKind => switch (widget.kind) {
        AstrologyContactKind.astrologer => AstrologyReadingKind.astrologer,
        AstrologyContactKind.pandit => AstrologyReadingKind.pandit,
        AstrologyContactKind.numerology => AstrologyReadingKind.numerology,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(astrologyContactsControllerProvider);
    final token = ref.watch(deviceAuthProvider.select((s) => s.accessToken));
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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PageIntro(
                headline: _headline,
                subtitle: _subtitle,
                accent: accent,
                assetPath: _headerAsset,
                count: state.contacts.length,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: state.loading && state.contacts.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(color: accent),
                      )
                    : state.contacts.isEmpty
                        ? _EmptyContactsState(accent: accent, isDark: isDark)
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              const gap = 14.0;
                              final columns = constraints.maxWidth >= 980
                                  ? 2
                                  : 1;
                              const tileHeight = 148.0;

                              return GridView.builder(
                                padding: const EdgeInsets.only(bottom: 8),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: gap,
                                  mainAxisSpacing: gap,
                                  mainAxisExtent: tileHeight,
                                ),
                                itemCount: state.contacts.length,
                                itemBuilder: (context, index) {
                                  return _ContactCard(
                                    contact: state.contacts[index],
                                    roleLabel: _roleLabel,
                                    accent: accent,
                                    secondaryAccent:
                                        _readingKind.secondaryAccent,
                                    accessToken: token,
                                  );
                                },
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

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.headline,
    required this.subtitle,
    required this.accent,
    required this.assetPath,
    required this.count,
  });

  final String headline;
  final String subtitle;
  final Color accent;
  final String assetPath;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isDark
              ? [const Color(0xFF24184A), const Color(0xFF1C143F)]
              : [
                  Colors.white,
                  accent.withValues(alpha: 0.06),
                  accent.withValues(alpha: 0.12),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: isDark ? 0.35 : 0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(5),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.auto_awesome, color: accent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? accent.withValues(alpha: 0.22)
                    : accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 1 ? 'guide' : 'guides',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyContactsState extends StatelessWidget {
  const _EmptyContactsState({required this.accent, required this.isDark});

  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 42,
            color: accent.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 12),
          Text(
            'Coming soon',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Guides will appear here once added in admin.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.65)
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends ConsumerStatefulWidget {
  const _ContactCard({
    required this.contact,
    required this.roleLabel,
    required this.accent,
    required this.secondaryAccent,
    required this.accessToken,
  });

  final AstrologyContact contact;
  final String roleLabel;
  final Color accent;
  final Color secondaryAccent;
  final String? accessToken;

  @override
  ConsumerState<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends ConsumerState<_ContactCard> {
  bool _revealed = false;
  bool _revealing = false;

  Future<void> _reveal() async {
    if (_revealed || _revealing) return;
    setState(() => _revealing = true);
    try {
      await ref
          .read(astrologyContactsRepositoryProvider)
          .reveal(widget.contact.id);
      final eventKey = switch (widget.contact.kind) {
        AstrologyContactKind.astrologer =>
          ServiceEventKeys.astrologyAstrologerShowNumber,
        AstrologyContactKind.pandit =>
          ServiceEventKeys.astrologyPanditShowNumber,
        AstrologyContactKind.numerology =>
          ServiceEventKeys.astrologyNumerologyShowNumber,
      };
      // ignore: discarded_futures
      ref.read(serviceAnalyticsTrackerProvider).track(
            eventKey,
            metadata: {
              'contactId': widget.contact.id,
              'name': widget.contact.name,
            },
          );
      if (!mounted) return;
      setState(() {
        _revealed = true;
        _revealing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _revealed = true;
        _revealing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accent;
    final photoUrl = _absolutePhotoUrl(widget.contact.photoUrl);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C143F) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? accent.withValues(alpha: 0.38)
              : const Color(0xFFE8EEF6),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 132,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PhotoHero(
                  name: widget.contact.name,
                  photoUrl: photoUrl,
                  accessToken: widget.accessToken,
                  accent: accent,
                  secondaryAccent: widget.secondaryAccent,
                  showComplete: true,
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _RoleChip(
                    label: widget.roleLabel,
                    accent: accent,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.contact.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RatingPill(rating: widget.contact.rating),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MiniStars(rating: widget.contact.rating),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _revealed
                        ? _RevealedPhone(
                            key: const ValueKey('phone'),
                            phone: _formatPhone(widget.contact.phone),
                            accent: accent,
                          )
                        : _ShowNumberButton(
                            key: const ValueKey('cta'),
                            accent: accent,
                            revealing: _revealing,
                            onTap: _reveal,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFCD34D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: Color(0xFF9A3412),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoHero extends StatelessWidget {
  const _PhotoHero({
    required this.name,
    required this.photoUrl,
    required this.accessToken,
    required this.accent,
    required this.secondaryAccent,
    this.showComplete = false,
  });

  final String name;
  final String? photoUrl;
  final String? accessToken;
  final Color accent;
  final Color secondaryAccent;
  final bool showComplete;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();

    Widget placeholder() {
      return Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(accent, Colors.white, 0.55)!,
                  Color.lerp(secondaryAccent, Colors.white, 0.35)!,
                  accent.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          CustomPaint(
            painter: _OrbitBackdropPainter(
              accent: accent,
              secondary: secondaryAccent,
            ),
          ),
          Center(
            child: Container(
              width: showComplete ? 72 : 92,
              height: showComplete ? 72 : 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Color.lerp(accent, Colors.white, 0.75)!,
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: showComplete ? 32 : 40,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (photoUrl == null || accessToken == null || accessToken!.isEmpty) {
      return placeholder();
    }

    final headers = {'Authorization': 'Bearer $accessToken'};

    // Horizontal cards: contain the full photo. Vertical legacy: soft cover fill.
    if (showComplete) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: accent.withValues(alpha: 0.12)),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Transform.scale(
              scale: 1.08,
              child: Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.center,
                headers: headers,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          ColoredBox(color: Colors.white.withValues(alpha: 0.12)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Image.network(
              photoUrl!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              headers: headers,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => placeholder(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return placeholder();
              },
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: accent.withValues(alpha: 0.18)),
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Transform.scale(
            scale: 1.12,
            child: Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              headers: headers,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.08)),
        Image.network(
          photoUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: const Alignment(0, -0.28),
          headers: headers,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => placeholder(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return placeholder();
          },
        ),
      ],
    );
  }
}

class _OrbitBackdropPainter extends CustomPainter {
  const _OrbitBackdropPainter({
    required this.accent,
    required this.secondary,
  });

  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.46);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 1; i <= 4; i++) {
      paint.color = Colors.white.withValues(alpha: 0.12 + i * 0.04);
      canvas.drawCircle(center, 28.0 + i * 18.0, paint);
    }

    final soft = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, 22, soft);

    final spark = Paint()..color = Colors.white.withValues(alpha: 0.45);
    final sparks = [
      Offset(size.width * 0.16, size.height * 0.22),
      Offset(size.width * 0.84, size.height * 0.28),
      Offset(size.width * 0.22, size.height * 0.72),
      Offset(size.width * 0.78, size.height * 0.68),
      Offset(size.width * 0.5, size.height * 0.14),
    ];
    for (final p in sparks) {
      canvas.drawCircle(p, 2.2, spark);
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = secondary.withValues(alpha: 0.35);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 78),
      -math.pi * 0.2,
      math.pi * 0.55,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitBackdropPainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.secondary != secondary;
  }
}

class _MiniStars extends StatelessWidget {
  const _MiniStars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: EdgeInsets.only(right: i == 5 ? 0 : 1),
            child: Icon(
              rating >= i
                  ? Icons.star_rounded
                  : rating >= i - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              size: 17,
              color: rating >= i - 0.5
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFD1D5DB),
            ),
          ),
      ],
    );
  }
}

class _ShowNumberButton extends StatelessWidget {
  const _ShowNumberButton({
    super.key,
    required this.accent,
    required this.revealing,
    required this.onTap,
  });

  final Color accent;
  final bool revealing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: revealing ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent,
                Color.lerp(accent, const Color(0xFF312E81), 0.28)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (revealing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.phone_rounded, size: 17, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  revealing ? 'Opening…' : 'Show number',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.1,
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

class _RevealedPhone extends StatelessWidget {
  const _RevealedPhone({
    super.key,
    required this.phone,
    required this.accent,
  });

  final String phone;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_in_talk_rounded, size: 18, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              phone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: accent,
              ),
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
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }
  if (digits.length == 12 && digits.startsWith('91')) {
    return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
  }
  return phone;
}
