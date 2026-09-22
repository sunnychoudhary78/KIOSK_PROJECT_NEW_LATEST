import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_kiosk/features/otp_print/presentation/otp_pdf_preview.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_hold.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class OtpPrintPage extends ConsumerStatefulWidget {
  const OtpPrintPage({super.key});

  @override
  ConsumerState<OtpPrintPage> createState() => _OtpPrintPageState();
}

class _OtpPrintPageState extends ConsumerState<OtpPrintPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _endSession() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpPrintControllerProvider);
    final controller = ref.read(otpPrintControllerProvider.notifier);

    ref.listen(otpPrintControllerProvider, (previous, next) {
      ref.read(kioskSessionHoldProvider.notifier).set(
            printing: next.phase == OtpPrintPhase.printing,
          );
    });

    return VisitorSessionPopScope(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OTP Print'),
          actions: [
            if (state.phase != OtpPrintPhase.enterOtp &&
                state.phase != OtpPrintPhase.redeeming)
              TextButton(
                onPressed: controller.reset,
                child: const Text('New OTP'),
              ),
          ],
        ),
        body: switch (state.phase) {
          OtpPrintPhase.redeeming || OtpPrintPhase.preparingPreview => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    state.phase == OtpPrintPhase.preparingPreview
                        ? 'Preparing document preview…'
                        : 'Fetching documents…',
                  ),
                ],
              ),
            ),
          OtpPrintPhase.previewing || OtpPrintPhase.printing
              when state.previewBytes != null =>
            Padding(
              padding: const EdgeInsets.all(8),
              child: OtpPdfPreviewPage(
                title: state.previewDoc?.fileName ?? 'Document',
                pdfBytes: state.previewBytes!,
                printing: state.phase == OtpPrintPhase.printing,
                error: state.error,
                message: state.message,
                onBack: controller.backToDocuments,
                onPrint: controller.confirmPrint,
                onDone: _endSession,
              ),
            ),
          OtpPrintPhase.documents || OtpPrintPhase.done => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    state.redeemResult?.title ?? 'Your documents',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (state.message != null) Text(state.message!),
                  if (state.error != null)
                    Text(
                      state.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: state.documents.isEmpty
                        ? const Center(child: Text('No documents for this OTP.'))
                        : ListView.separated(
                            itemCount: state.documents.length,
                            separatorBuilder: (_, _) => const Divider(),
                            itemBuilder: (context, index) {
                              final doc = state.documents[index];
                              return ListTile(
                                leading: const Icon(Icons.picture_as_pdf_outlined),
                                title: Text(doc.fileName),
                                subtitle: Text('${doc.pageCount} page(s)'),
                                trailing: FilledButton(
                                  onPressed: state.loading
                                      ? null
                                      : () => controller.preparePreview(doc),
                                  child: const Text('Preview'),
                                ),
                              );
                            },
                          ),
                  ),
                  if (state.phase == OtpPrintPhase.done) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _endSession,
                      child: const Text('Done'),
                    ),
                  ],
                ],
              ),
            ),
          _ => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter the OTP sent by SMS',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'OTP',
                    ),
                    onSubmitted: (value) {
                      if (!state.loading && value.trim().isNotEmpty) {
                        controller.redeem(value.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: state.loading
                        ? null
                        : () => controller.redeem(_controller.text.trim()),
                    child: Text(state.loading ? 'Fetching…' : 'Continue'),
                  ),
                  const SizedBox(height: 16),
                  if (state.error != null)
                    Text(
                      state.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                ],
              ),
            ),
        },
      ),
    );
  }
}
