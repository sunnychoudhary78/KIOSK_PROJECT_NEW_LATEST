import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/otp_print/application/challenge_status.dart';
import 'package:skp_mobile/features/otp_print/application/open_print_session.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_models.dart';
import 'package:skp_mobile/features/otp_print/application/print_history_controller.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
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
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(printHistoryProvider);
    final theme = Theme.of(context);

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkpPageHeader(
            title: l10n.historyTitle,
            subtitle: l10n.historyHelper,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => SkpEmptyState(
                icon: Icons.error_outline_rounded,
                title: error.toString(),
                message: l10n.historyHelper,
                actionLabel: l10n.retry,
                onAction: () => ref.read(printHistoryProvider.notifier).refresh(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SkpEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.historyEmpty,
                    message: l10n.historyEmptyHelper,
                    actionLabel: l10n.uploadDocuments,
                    onAction: () =>
                        Navigator.of(context).pushNamed(AppRoutes.otpPrint),
                  );
                }
                final active = items.where((item) => item.isActive).toList();
                final past = items.where((item) => !item.isActive).toList();
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(printHistoryProvider.notifier).refresh(),
                  child: ListView(
                    children: [
                      if (active.isNotEmpty) ...[
                        Text(
                          l10n.activeSection,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: SkpColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final item in active) ...[
                          _HistoryTile(challenge: item),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                      ],
                      if (past.isNotEmpty) ...[
                        Text(
                          l10n.pastSection,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: SkpColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final item in past) ...[
                          _HistoryTile(challenge: item),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.challenge});

  final OtpChallenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (label, color) = challengeStatusStyle(l10n, challenge);
    final title = challenge.displayLabel.isEmpty
        ? l10n.documentsReady
        : challenge.displayLabel;
    final colorLabel =
        challenge.printColorMode == 'color' ? l10n.colorColor : l10n.colorBw;

    return SkpPanelCard(
      onTap: challenge.isActive
          ? () => openPrintSession(context, ref, challenge)
          : null,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const SkpIconWell(icon: Icons.description_outlined, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.pagesColorFiles(
                    challenge.pageCount,
                    colorLabel,
                    challenge.documents.length,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: SkpColors.muted,
                  ),
                ),
              ],
            ),
          ),
          SkpStatusChip(label: label, color: color),
        ],
      ),
    );
  }
}
