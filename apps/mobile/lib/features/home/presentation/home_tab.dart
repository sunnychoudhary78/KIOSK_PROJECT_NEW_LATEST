import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/format.dart';
import 'package:skp_mobile/core/navigation/nav_tab.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/otp_print/application/challenge_status.dart';
import 'package:skp_mobile/features/otp_print/application/open_print_session.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_mobile/features/otp_print/application/print_history_controller.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(citizenAuthProvider);
    final history = ref.watch(printHistoryProvider);
    final l10n = AppLocalizations.of(context);
    final phone = maskPhone(auth.phone);
    final greeting = phone.isEmpty ? l10n.greetingReady : l10n.signedInAs(phone);
    final active = history.asData == null
        ? null
        : activeChallengeOf(history.asData!.value);

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      body: ListView(
        children: [
          _DashboardHeader(
            brand: l10n.brandName,
            greeting: greeting,
            onMenu: () => showSkpAppMenu(context, ref),
            onProfile: () =>
                ref.read(navTabProvider.notifier).select(NavTabs.profile),
            profileTooltip: l10n.tabProfile,
          ),
          const SizedBox(height: 20),
          _HeroPrintCard(
            title: l10n.homeHeadline,
            helper: l10n.homeHelper,
          ),
          if (active != null) ...[
            const SizedBox(height: 16),
            _ActiveSessionCard(challenge: active),
          ],
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.92,
            children: [
              _ServiceGridCard(
                icon: Icons.print_rounded,
                title: l10n.uploadTileTitle,
                subtitle: l10n.uploadTileSubtitle,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.otpPrint),
              ),
              _ServiceGridCard(
                icon: Icons.handyman_outlined,
                title: l10n.findServicesTileTitle,
                subtitle: l10n.findServicesTileSubtitle,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.findServices),
              ),
              _ServiceGridCard(
                icon: Icons.local_gas_station_outlined,
                title: l10n.fuelStationsTileTitle,
                subtitle: l10n.fuelStationsTileSubtitle,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.fuelStations),
              ),
              _ServiceGridCard(
                icon: Icons.auto_awesome_outlined,
                title: l10n.astrologyPanditTileTitle,
                subtitle: l10n.astrologyPanditTileSubtitle,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.astrologyPandit),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _NearbyWideCard(
            title: l10n.nearbyTileTitle,
            subtitle: l10n.nearbyTileSubtitle,
            onTap: () =>
                ref.read(navTabProvider.notifier).select(NavTabs.nearby),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.brand,
    required this.greeting,
    required this.onMenu,
    required this.onProfile,
    required this.profileTooltip,
  });

  final String brand;
  final String greeting;
  final VoidCallback onMenu;
  final VoidCallback onProfile;
  final String profileTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _HeaderIconButton(
          icon: Icons.menu_rounded,
          onPressed: onMenu,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Text(
                brand,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                greeting,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: SkpColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _HeaderIconButton(
          icon: Icons.person_outline_rounded,
          onPressed: onProfile,
          tooltip: profileTooltip,
          circular: true,
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.circular = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: SkpColors.panel,
        foregroundColor: SkpColors.accent,
        side: const BorderSide(color: SkpColors.line),
        shape: circular
            ? const CircleBorder()
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
      ),
      icon: Icon(icon),
    );
  }
}

class _HeroPrintCard extends StatelessWidget {
  const _HeroPrintCard({required this.title, required this.helper});

  final String title;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A8F78),
            Color(0xFF0F6A5A),
            Color(0xFF0A5246),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: SkpColors.accent.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -10,
              child: Icon(
                Icons.print_rounded,
                size: 120,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          helper,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: 56,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7DFFC8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _KioskIllustration(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KioskIllustration extends StatelessWidget {
  const _KioskIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 118,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 78,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFB7E8D8), width: 3),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 46,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: SkpColors.accent,
                    size: 22,
                  ),
                ),
                const Spacer(),
                Container(
                  height: 10,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(
                    color: SkpColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7DFFC8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.print_rounded,
                size: 16,
                color: SkpColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceGridCard extends StatelessWidget {
  const _ServiceGridCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: SkpColors.panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: SkpColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SkpColors.accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: SkpColors.accent, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: SkpColors.muted,
                    height: 1.3,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: SkpColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyWideCard extends StatelessWidget {
  const _NearbyWideCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: SkpColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: SkpColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SkpColors.accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: SkpColors.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: SkpColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: SkpColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveSessionCard extends ConsumerWidget {
  const _ActiveSessionCard({required this.challenge});

  final OtpChallenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (label, color) = challengeStatusStyle(l10n, challenge);
    final expiresAt = DateTime.tryParse(challenge.expiresAt)?.toLocal();
    final remaining = expiresAt == null
        ? null
        : formatRemaining(expiresAt, expiredLabel: l10n.expiredLabel);

    return SkpPanelCard(
      onTap: () => openPrintSession(context, ref, challenge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.activeSessionTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SkpStatusChip(label: label, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            challenge.displayLabel.isEmpty
                ? l10n.documentsReady
                : challenge.displayLabel,
            style: theme.textTheme.bodyMedium,
          ),
          if (remaining != null) ...[
            const SizedBox(height: 8),
            Text(
              challenge.isExpired ? l10n.otpExpired : l10n.validFor(remaining),
              style: theme.textTheme.bodySmall?.copyWith(
                color: challenge.isExpired ? SkpColors.danger : SkpColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (challenge.status == 'awaiting_payment')
            SkpPrimaryButton(
              label: l10n.pay,
              onPressed: () => openPrintSession(context, ref, challenge),
            )
          else ...[
            SkpPrimaryButton(
              label: l10n.findKiosk,
              onPressed: () =>
                  ref.read(navTabProvider.notifier).select(NavTabs.nearby),
            ),
            const SizedBox(height: 4),
            SkpTextLink(
              label: l10n.resendOtp,
              onPressed: () async {
                await ref
                    .read(otpPrintControllerProvider.notifier)
                    .loadChallenge(challenge.id);
                await ref.read(otpPrintControllerProvider.notifier).resendOtp();
              },
            ),
          ],
        ],
      ),
    );
  }
}
