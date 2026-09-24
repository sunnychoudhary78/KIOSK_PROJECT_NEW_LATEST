import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_hold.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class OtpPrintPage extends ConsumerStatefulWidget {
  const OtpPrintPage({super.key});

  @override
  ConsumerState<OtpPrintPage> createState() => _OtpPrintPageState();
}

class _OtpPrintPageState extends ConsumerState<OtpPrintPage> {
  static const _otpLength = 6;
  String _otp = '';

  Future<void> _endSession() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  void _appendDigit(String digit) {
    if (_otp.length >= _otpLength) {
      return;
    }
    setState(() => _otp += digit);
  }

  void _backspace() {
    if (_otp.isEmpty) {
      return;
    }
    setState(() => _otp = _otp.substring(0, _otp.length - 1));
  }

  void _clear() => setState(() => _otp = '');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpPrintControllerProvider);
    final controller = ref.read(otpPrintControllerProvider.notifier);

    ref.listen(otpPrintControllerProvider, (previous, next) {
      ref.read(kioskSessionHoldProvider.notifier).set(
            printing: next.phase == OtpPrintPhase.printing,
          );
      if (previous?.phase != OtpPrintPhase.enterOtp &&
          next.phase == OtpPrintPhase.enterOtp) {
        _otp = '';
      }
    });

    final previewing = state.phase == OtpPrintPhase.previewing ||
        state.phase == OtpPrintPhase.printing;
    final listing = state.phase == OtpPrintPhase.documents ||
        state.phase == OtpPrintPhase.done;
    final entering = state.phase == OtpPrintPhase.enterOtp ||
        state.phase == OtpPrintPhase.error;

    Widget? leading;
    Widget? trailing;
    String? step;
    if (entering) {
      leading = KioskGhostButton(label: 'Cancel', onPressed: _endSession);
      trailing = KioskPrimaryButton(
        label: 'Continue',
        loading: state.loading,
        onPressed: state.loading || _otp.length < 4
            ? null
            : () => controller.redeem(_otp),
      );
      step = 'Enter code';
    } else if (previewing) {
      leading = KioskGhostButton(
        label: 'Back',
        icon: Icons.arrow_back,
        onPressed: state.phase == OtpPrintPhase.printing ? null : controller.backToDocuments,
      );
      trailing = KioskPrimaryButton(
        label: state.phase == OtpPrintPhase.printing ? 'Printing…' : 'Print',
        icon: Icons.print,
        loading: state.phase == OtpPrintPhase.printing,
        onPressed: state.phase == OtpPrintPhase.printing ? null : controller.confirmPrint,
      );
      step = 'Preview';
    } else if (listing) {
      leading = KioskGhostButton(
        label: 'New OTP',
        onPressed: () {
          _clear();
          controller.reset();
        },
      );
      trailing = state.phase == OtpPrintPhase.done
          ? KioskPrimaryButton(label: 'Done', onPressed: _endSession)
          : null;
      step = 'Documents';
    }

    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'OTP Print',
        onHome: _endSession,
        stepLabel: step,
        footerLeading: leading,
        footerTrailing: trailing,
        body: switch (state.phase) {
          OtpPrintPhase.redeeming || OtpPrintPhase.preparingPreview => KioskLoading(
              message: state.phase == OtpPrintPhase.preparingPreview
                  ? 'Preparing document preview…'
                  : 'Fetching documents…',
            ),
          OtpPrintPhase.previewing || OtpPrintPhase.printing
              when state.previewBytes != null =>
            KioskPdfPreview(
              title: state.previewDoc?.fileName ?? 'Document',
              pdfBytes: state.previewBytes!,
              error: state.error,
              message: state.message,
            ),
          OtpPrintPhase.documents || OtpPrintPhase.done => _DocumentList(
              title: state.redeemResult?.title ?? 'Your documents',
              message: state.message,
              error: state.error,
              empty: state.documents.isEmpty,
              children: [
                for (final doc in state.documents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: KioskDocCard(
                      title: doc.fileName,
                      subtitle:
                          '${doc.pageCount} page(s) · ${state.redeemResult?.printColorLabel ?? 'B/W'}',
                      actionLabel: 'Preview',
                      onAction: state.loading ? null : () => controller.preparePreview(doc),
                    ),
                  ),
              ],
            ),
          _ => _OtpEntry(
              otp: _otp,
              error: state.error,
              onDigit: _appendDigit,
              onBackspace: _backspace,
              onClear: _clear,
            ),
        },
      ),
    );
  }
}

class _OtpEntry extends StatelessWidget {
  const _OtpEntry({
    required this.otp,
    required this.error,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  final String otp;
  final String? error;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the OTP sent by SMS',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Use the keypad. No phone keyboard is needed.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: SkpColors.muted,
                      ),
                ),
                const Spacer(),
                KioskPinField(value: otp),
                const Spacer(),
                if (error != null)
                  KioskStatusBanner(
                    message: error!,
                    tone: KioskBannerTone.danger,
                    icon: Icons.error_outline,
                  )
                else
                  const SizedBox(height: 56),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 4,
            child: KioskNumericKeypad(
              onDigit: onDigit,
              onBackspace: onBackspace,
              onClear: onClear,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({
    required this.title,
    required this.children,
    required this.empty,
    this.message,
    this.error,
  });

  final String title;
  final List<Widget> children;
  final bool empty;
  final String? message;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            KioskStatusBanner(
              message: error!,
              tone: KioskBannerTone.danger,
              icon: Icons.error_outline,
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: empty
                ? const KioskEmpty(message: 'No documents for this OTP.')
                : ListView(children: children),
          ),
        ],
      ),
    );
  }
}
