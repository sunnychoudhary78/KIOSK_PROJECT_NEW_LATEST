import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/digilocker_print/application/digilocker_controller.dart';
import 'package:skp_kiosk/features/digilocker_print/presentation/digilocker_auth_webview.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_hold.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class DigilockerPrintPage extends ConsumerStatefulWidget {
  const DigilockerPrintPage({super.key});

  @override
  ConsumerState<DigilockerPrintPage> createState() => _DigilockerPrintPageState();
}

class _DigilockerPrintPageState extends ConsumerState<DigilockerPrintPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(digilockerControllerProvider.notifier).start());
  }

  Future<void> _endSessionAndGoHome() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(digilockerControllerProvider);
    final controller = ref.read(digilockerControllerProvider.notifier);

    ref.listen(digilockerControllerProvider, (previous, next) {
      ref.read(kioskSessionHoldProvider.notifier).set(
            printing: next.phase == DigilockerPhase.printing,
            awaitingConsent: next.phase == DigilockerPhase.awaitingConsent,
          );
    });

    final previewing = state.phase == DigilockerPhase.previewing ||
        state.phase == DigilockerPhase.printing;
    final listing = state.phase == DigilockerPhase.ready ||
        state.phase == DigilockerPhase.done;

    Widget? leading;
    Widget? trailing;
    String? step;
    if (previewing) {
      leading = KioskGhostButton(
        label: 'Back',
        icon: Icons.arrow_back,
        onPressed: state.phase == DigilockerPhase.printing
            ? null
            : controller.backToDocuments,
      );
      trailing = KioskPrimaryButton(
        label: state.phase == DigilockerPhase.printing ? 'Printing…' : 'Print',
        icon: Icons.print,
        loading: state.phase == DigilockerPhase.printing,
        onPressed: state.phase == DigilockerPhase.printing
            ? null
            : () => controller.confirmPrint(),
      );
      step = 'Preview';
    } else if (listing) {
      leading = KioskGhostButton(label: 'End session', onPressed: _endSessionAndGoHome);
      step = 'Documents';
    } else if (state.phase == DigilockerPhase.awaitingConsent) {
      leading = KioskGhostButton(label: 'Cancel', onPressed: _endSessionAndGoHome);
      step = 'Sign in';
    }

    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'DigiLocker Print',
        onHome: _endSessionAndGoHome,
        stepLabel: step,
        footerLeading: leading,
        footerTrailing: trailing,
        body: switch (state.phase) {
          DigilockerPhase.awaitingConsent => _AuthBody(
              authorizationUrl: state.authorizationUrl,
              error: state.error,
              onCallback: controller.onAuthRedirectCompleted,
              onWebViewError: controller.onWebViewError,
              onActivity: () =>
                  ref.read(kioskSessionControllerProvider.notifier).noteActivity(),
            ),
          DigilockerPhase.idle ||
          DigilockerPhase.loadingDocs ||
          DigilockerPhase.preparingPreview =>
            KioskLoading(
              message: state.phase == DigilockerPhase.preparingPreview
                  ? 'Preparing document preview…'
                  : (state.message ?? 'Loading…'),
            ),
          DigilockerPhase.previewing || DigilockerPhase.printing
              when state.previewBytes != null =>
            KioskPdfPreview(
              title: state.previewTitle ?? 'Document',
              pdfBytes: state.previewBytes!,
              error: state.error,
            ),
          _ => Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.error != null)
                    KioskStatusBanner(
                      message: state.error!,
                      tone: KioskBannerTone.danger,
                      icon: Icons.error_outline,
                    ),
                  if (state.message != null) ...[
                    const SizedBox(height: 8),
                    Text(state.message!, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: state.documents.isEmpty
                        ? const KioskEmpty(
                            message:
                                'No DigiLocker documents were shared for this session.',
                          )
                        : ListView.separated(
                            itemCount: state.documents.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final doc = state.documents[index];
                              return KioskDocCard(
                                title: doc.name,
                                subtitle: doc.subtitle.isEmpty ? doc.issuer : doc.subtitle,
                                actionLabel: 'Preview',
                                onAction: state.loading
                                    ? null
                                    : () => controller.preparePreview(doc.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
        },
      ),
    );
  }
}

class _AuthBody extends StatelessWidget {
  const _AuthBody({
    required this.authorizationUrl,
    required this.error,
    required this.onCallback,
    required this.onWebViewError,
    required this.onActivity,
  });

  final String? authorizationUrl;
  final String? error;
  final VoidCallback onCallback;
  final ValueChanged<String> onWebViewError;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    if (authorizationUrl == null) {
      return const KioskLoading(message: 'Starting DigiLocker…');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            KioskStatusBanner(
              message: error!,
              tone: KioskBannerTone.danger,
              icon: Icons.error_outline,
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: DigilockerAuthWebView(
              authorizationUrl: authorizationUrl!,
              onCallbackReached: onCallback,
              onError: onWebViewError,
              onActivity: onActivity,
            ),
          ),
        ],
      ),
    );
  }
}
