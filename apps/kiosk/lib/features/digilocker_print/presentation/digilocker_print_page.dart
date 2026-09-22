import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/features/digilocker_print/application/digilocker_controller.dart';
import 'package:skp_kiosk/features/digilocker_print/presentation/digilocker_auth_webview.dart';
import 'package:skp_kiosk/features/digilocker_print/presentation/digilocker_pdf_preview.dart';
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

    return VisitorSessionPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DigiLocker Print'),
          actions: [
            TextButton(
              onPressed: _endSessionAndGoHome,
              child: const Text('End session'),
            ),
          ],
        ),
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
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    state.phase == DigilockerPhase.preparingPreview
                        ? 'Preparing document preview…'
                        : (state.message ?? 'Loading…'),
                  ),
                ],
              ),
            ),
          DigilockerPhase.previewing || DigilockerPhase.printing
              when state.previewBytes != null =>
            Padding(
              padding: const EdgeInsets.all(8),
              child: DigilockerPdfPreviewPage(
                title: state.previewTitle ?? 'Document',
                pdfBytes: state.previewBytes!,
                printing: state.phase == DigilockerPhase.printing,
                error: state.error,
                onBack: controller.backToDocuments,
                onPrint: () => controller.confirmPrint(),
                onDone: _endSessionAndGoHome,
              ),
            ),
          _ => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.error != null)
                    Text(
                      state.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  if (state.message != null) Text(state.message!),
                  const SizedBox(height: 12),
                  Expanded(
                    child: state.documents.isEmpty
                        ? const Center(
                            child: Text(
                              'No DigiLocker documents were shared for this session.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: state.documents.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final doc = state.documents[index];
                              return ListTile(
                                title: Text(doc.name),
                                subtitle: Text(
                                  doc.subtitle.isEmpty ? doc.issuer : doc.subtitle,
                                ),
                                trailing: FilledButton(
                                  onPressed: state.loading
                                      ? null
                                      : () => controller.preparePreview(doc.id),
                                  child: const Text('Preview'),
                                ),
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
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ),
        Expanded(
          child: DigilockerAuthWebView(
            authorizationUrl: authorizationUrl!,
            onCallbackReached: onCallback,
            onError: onWebViewError,
            onActivity: onActivity,
          ),
        ),
      ],
    );
  }
}
