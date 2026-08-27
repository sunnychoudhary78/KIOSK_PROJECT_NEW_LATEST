import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_controller.dart';

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

  String _formatRemaining(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    final totalSeconds = remaining.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s left';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} left';
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
    final challenge = ref.watch(otpPrintControllerProvider).asData?.value;

    if (challenge == null) {
      return SkpScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No active print session.',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload documents first to receive a print OTP.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SkpColors.muted,
                ),
              ),
              const SizedBox(height: 20),
              SkpPrimaryButton(
                label: 'Upload documents',
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed(AppRoutes.otpPrint),
              ),
            ],
          ),
        ),
      );
    }

    final expiresAt = DateTime.tryParse(challenge.expiresAt)?.toLocal();
    final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());

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
                  color: SkpColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sms_rounded,
                  size: 40,
                  color: SkpColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'OTP sent by SMS',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Check your messages, then enter the OTP on the kiosk to preview and print.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SkpColors.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SkpColors.line),
            ),
            child: Column(
              children: [
                Text(
                  challenge.documentLabel.isEmpty
                      ? 'Documents ready'
                      : challenge.documentLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${challenge.pageCount} page(s) · ${challenge.documents.length} file(s)',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: SkpColors.muted,
                  ),
                ),
                if (expiresAt != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: expired
                          ? SkpColors.danger.withValues(alpha: 0.08)
                          : SkpColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      expired
                          ? 'OTP expired'
                          : 'Valid for ${_formatRemaining(expiresAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: expired ? SkpColors.danger : SkpColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(flex: 2),
          SkpPrimaryButton(
            label: 'Done',
            onPressed: _done,
          ),
          const SizedBox(height: 8),
          SkpSecondaryButton(
            label: 'Upload more documents',
            onPressed: _uploadMore,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
