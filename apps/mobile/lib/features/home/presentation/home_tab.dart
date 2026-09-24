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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final phone = maskPhone(auth.phone);
    final greeting = phone.isEmpty ? l10n.greetingReady : l10n.signedInAs(phone);
    final active = history.asData == null
        ? null
        : activeChallengeOf(history.asData!.value);

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.brandName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      greeting,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: SkpColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(navTabProvider.notifier).select(NavTabs.profile),
                style: IconButton.styleFrom(
                  backgroundColor: SkpColors.panel,
                  side: const BorderSide(color: SkpColors.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.person_outline_rounded),
                tooltip: l10n.tabProfile,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(l10n.homeHeadline, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            l10n.homeHelper,
            style: theme.textTheme.bodyMedium?.copyWith(color: SkpColors.muted),
          ),
          if (active != null) ...[
            const SizedBox(height: 20),
            _ActiveSessionCard(challenge: active),
          ],
          const SizedBox(height: 20),
          SkpActionTile(
            icon: Icons.print_rounded,
            title: l10n.uploadTileTitle,
            subtitle: l10n.uploadTileSubtitle,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.otpPrint),
          ),
          const SizedBox(height: 14),
          SkpActionTile(
            icon: Icons.location_on_outlined,
            title: l10n.nearbyTileTitle,
            subtitle: l10n.nearbyTileSubtitle,
            onTap: () => ref.read(navTabProvider.notifier).select(NavTabs.nearby),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.howItWorksTitle,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          SkpStepsRow(
            steps: [l10n.stepUpload, l10n.stepOtpSms, l10n.stepPrint],
          ),
        ],
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
