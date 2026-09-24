import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/format.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/otp_print/application/open_print_session.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

class OtpPrintSuccessPage extends ConsumerStatefulWidget {
  const OtpPrintSuccessPage({super.key});

  @override
  ConsumerState<OtpPrintSuccessPage> createState() => _OtpPrintSuccessPageState();
}

class _OtpPrintSuccessPageState extends ConsumerState<OtpPrintSuccessPage>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late final AnimationController _pop;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _scale = CurvedAnimation(parent: _pop, curve: Curves.easeOutBack);
    _pop.forward();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pop.dispose();
    super.dispose();
  }

  void _uploadMore() {
    ref.read(otpPrintControllerProvider.notifier).clear();
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.otpPrint,
      (route) => route.settings.name == AppRoutes.home || route.isFirst,
    );
  }

  void _done() {
    ref.read(otpPrintControllerProvider.notifier).clear();
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final challenge = ref.watch(otpPrintControllerProvider).asData?.value;

    if (challenge == null) {
      return SkpScaffold(
        body: SkpEmptyState(
          icon: Icons.sms_outlined,
          title: l10n.noActiveSession,
          message: l10n.noActiveSessionHelper,
          actionLabel: l10n.uploadDocuments,
          onAction: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.otpPrint),
        ),
      );
    }

    final expiresAt = DateTime.tryParse(challenge.expiresAt)?.toLocal();
    final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final remaining = expiresAt == null
        ? null
        : formatRemaining(expiresAt, expiredLabel: l10n.expiredLabel);
    final colorLabel =
        challenge.printColorMode == 'color' ? l10n.colorColor : l10n.colorBw;

    return SkpScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 1),
          ScaleTransition(
            scale: _scale,
            child: Center(
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SkpColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 44,
                  color: SkpColors.success,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.otpSentTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.otpSentHelper,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 28),
          SkpPanelCard(
            child: Column(
              children: [
                Text(
                  challenge.documentLabel.isEmpty
                      ? l10n.documentsReady
                      : challenge.documentLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.pagesColorFiles(
                    challenge.pageCount,
                    colorLabel,
                    challenge.documents.length,
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: SkpColors.muted,
                  ),
                ),
                if (remaining != null) ...[
                  const SizedBox(height: 14),
                  SkpStatusChip(
                    label: expired ? l10n.otpExpired : l10n.validFor(remaining),
                    color: expired ? SkpColors.danger : SkpColors.accent,
                  ),
                ],
              ],
            ),
          ),
          const Spacer(flex: 2),
          SkpPrimaryButton(
            label: l10n.findKiosk,
            onPressed: () => goToNearbyTab(context, ref),
          ),
          const SizedBox(height: 8),
          SkpSecondaryButton(
            label: l10n.uploadMore,
            onPressed: _uploadMore,
          ),
          const SizedBox(height: 4),
          SkpTextLink(
            label: l10n.done,
            onPressed: _done,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
