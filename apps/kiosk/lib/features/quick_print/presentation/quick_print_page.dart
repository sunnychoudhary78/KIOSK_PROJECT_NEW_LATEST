import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/ads/presentation/kiosk_wait_ads.dart';
import 'package:skp_kiosk/features/quick_print/application/quick_print_controller.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_hold.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class QuickPrintPage extends ConsumerStatefulWidget {
  const QuickPrintPage({super.key});

  @override
  ConsumerState<QuickPrintPage> createState() => _QuickPrintPageState();
}

class _QuickPrintPageState extends ConsumerState<QuickPrintPage> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(quickPrintControllerProvider.notifier).start());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _endSession() {
    return ref.read(kioskSessionControllerProvider.notifier).endVisitorSession(attract: false);
  }

  String _remaining(DateTime expiresAt) {
    final delta = expiresAt.difference(DateTime.now());
    if (delta.isNegative) return 'Expired';
    final minutes = delta.inMinutes;
    final seconds = delta.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickPrintControllerProvider);
    final controller = ref.read(quickPrintControllerProvider.notifier);

    ref.listen(quickPrintControllerProvider, (previous, next) {
      ref.read(kioskSessionHoldProvider.notifier).set(
            printing: next.phase == QuickPrintPhase.printing,
            waiting: next.phase == QuickPrintPhase.waiting ||
                next.phase == QuickPrintPhase.starting,
          );
    });

    final previewing = state.phase == QuickPrintPhase.previewing ||
        state.phase == QuickPrintPhase.printing;
    final listing =
        state.phase == QuickPrintPhase.documents || state.phase == QuickPrintPhase.done;

    Widget? leading;
    Widget? trailing;
    String? step;
    if (state.phase == QuickPrintPhase.waiting ||
        state.phase == QuickPrintPhase.starting ||
        state.phase == QuickPrintPhase.error) {
      leading = KioskGhostButton(label: 'Cancel', onPressed: _endSession);
      if (state.phase == QuickPrintPhase.error) {
        trailing = KioskPrimaryButton(
          label: 'Try again',
          onPressed: () => controller.start(),
        );
      }
      step = 'Scan';
    } else if (previewing) {
      leading = KioskGhostButton(
        label: 'Back',
        icon: Icons.arrow_back,
        onPressed: state.phase == QuickPrintPhase.printing ? null : controller.backToDocuments,
      );
      trailing = KioskPrimaryButton(
        label: state.phase == QuickPrintPhase.printing ? 'Printing…' : 'Print',
        icon: Icons.print,
        loading: state.phase == QuickPrintPhase.printing,
        onPressed: state.phase == QuickPrintPhase.printing ? null : controller.confirmPrint,
      );
      step = 'Preview';
    } else if (listing) {
      leading = KioskGhostButton(label: 'Done', onPressed: _endSession);
      trailing = state.phase == QuickPrintPhase.done
          ? KioskPrimaryButton(label: 'Finish', onPressed: _endSession)
          : KioskPrimaryButton(
              label: 'Finish',
              onPressed: controller.markDoneWithoutPrint,
            );
      step = 'Documents';
    }

    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'Quick Print',
        onHome: _endSession,
        stepLabel: step,
        footerLeading: leading,
        footerTrailing: trailing,
        body: switch (state.phase) {
          QuickPrintPhase.starting ||
          QuickPrintPhase.claiming ||
          QuickPrintPhase.preparingPreview =>
            KioskWaitAds(
              message: state.phase == QuickPrintPhase.preparingPreview
                  ? 'Preparing document preview…'
                  : state.phase == QuickPrintPhase.claiming
                      ? 'Fetching documents…'
                      : 'Starting session…',
            ),
          QuickPrintPhase.previewing || QuickPrintPhase.printing
              when state.previewBytes != null =>
            KioskPdfPreview(
              title: state.previewDoc?.fileName ?? 'Document',
              pdfBytes: state.previewBytes!,
              error: state.error,
              message: state.message,
            ),
          QuickPrintPhase.documents || QuickPrintPhase.done => Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.claim?.title ?? 'Your documents',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (state.message != null) ...[
                    const SizedBox(height: 8),
                    Text(state.message!, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 8),
                    Text(state.error!, style: const TextStyle(color: SkpColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final doc in state.documents)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: KioskDocCard(
                              title: doc.fileName,
                              subtitle:
                                  '${doc.pageCount} page(s) · ${state.claim?.printColorLabel ?? 'B/W'}',
                              actionLabel: 'Preview',
                              onAction: state.loading
                                  ? null
                                  : () => controller.preparePreview(doc),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          _ => _QrWait(
              publicUrl: state.session?.publicUrl,
              remaining: state.session == null
                  ? ''
                  : _remaining(state.session!.expiresAt),
              error: state.error,
              message: state.message,
            ),
        },
      ),
    );
  }
}

class _QrWait extends StatelessWidget {
  const _QrWait({
    required this.publicUrl,
    required this.remaining,
    this.error,
    this.message,
  });

  final String? publicUrl;
  final String remaining;
  final String? error;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scan with your phone', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Open the camera, scan the code, and upload PDFs in the browser. No app required.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
                ),
                const Spacer(),
                if (remaining.isNotEmpty)
                  Text(
                    'Expires in $remaining',
                    style: theme.textTheme.titleLarge?.copyWith(color: SkpColors.gold),
                  ),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(message!, style: theme.textTheme.titleMedium),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  KioskStatusBanner(
                    message: error!,
                    tone: KioskBannerTone.danger,
                    icon: Icons.error_outline,
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            width: 360,
            height: 360,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
            ),
            child: publicUrl == null || publicUrl!.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : QrImageView(
                    data: publicUrl!,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                  ),
          ),
        ],
      ),
    );
  }
}
