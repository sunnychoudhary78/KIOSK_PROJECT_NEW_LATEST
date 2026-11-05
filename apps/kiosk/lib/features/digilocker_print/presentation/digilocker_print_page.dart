import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/ads/presentation/kiosk_wait_ads.dart';
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

  Future<void> _endSessionAndGoHome() async {
    await ref.read(digilockerControllerProvider.notifier).abandonRetry();
    await ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  Future<void> _goBack() async {
    await ref.read(digilockerControllerProvider.notifier).endSession();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _verifyOtpAndShowQuota(DigilockerController controller) async {
    final summary = await controller.verifyPrintPhoneOtp();
    if (!mounted || summary == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Free print check'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.remainingLabel,
                style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                summary.printCostLine,
                style: Theme.of(dialogContext).textTheme.bodyLarge,
              ),
              if (summary.message != null &&
                  summary.message!.trim().isNotEmpty &&
                  !summary.freeEligible) ...[
                const SizedBox(height: 12),
                Text(
                  summary.message!,
                  style: Theme.of(dialogContext).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
          actions: [
            KioskPrimaryButton(
              label: 'OK',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    await controller.continueAfterQuotaSummary(summary);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(digilockerControllerProvider);
    final controller = ref.read(digilockerControllerProvider.notifier);

    ref.listen(digilockerControllerProvider, (previous, next) {
      ref.read(kioskSessionHoldProvider.notifier).set(
            printing: next.phase == DigilockerPhase.printing ||
                next.phase == DigilockerPhase.awaitingPayment ||
                next.phase == DigilockerPhase.choosingPayMethod ||
                next.phase == DigilockerPhase.enteringPhone ||
                next.phase == DigilockerPhase.choosingColorMode,
            awaitingConsent: next.phase == DigilockerPhase.awaitingConsent,
          );
    });

    final previewing = state.phase == DigilockerPhase.previewing ||
        state.phase == DigilockerPhase.printing;
    final listing = state.phase == DigilockerPhase.ready ||
        state.phase == DigilockerPhase.done;
    if ((kioskPrintingPaused(ref) || state.paperOut) &&
        state.phase != DigilockerPhase.printing) {
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: 'DigiLocker',
          onHome: _endSessionAndGoHome,
          body: const KioskPrintingPaused(),
        ),
      );
    }

    if (state.phase == DigilockerPhase.choosingColorMode) {
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: 'DigiLocker Print',
          onHome: _endSessionAndGoHome,
          stepLabel: 'Print mode',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: controller.backFromPrintFlow,
          ),
          body: _ChoiceBody(
            headline: 'Black & white or color?',
            subtitle: state.pendingDocumentTitle == null
                ? 'Choose how this document should print.'
                : 'Choose how “${state.pendingDocumentTitle}” should print.',
            error: state.error,
            left: _ChoiceCard(
              icon: Icons.filter_b_and_w,
              title: 'Black & white',
              subtitle: state.bwChargeRupees <= 0
                  ? 'Free on this kiosk'
                  : '₹${state.bwChargeRupees} per page',
              onPressed: () => controller.chooseColorMode('bw'),
            ),
            right: _ChoiceCard(
              icon: Icons.palette_outlined,
              title: 'Color',
              subtitle: state.colorChargeRupees <= 0
                  ? 'Free on this kiosk'
                  : '₹${state.colorChargeRupees} per page',
              onPressed: () => controller.chooseColorMode('color'),
            ),
          ),
        ),
      );
    }

    if (state.phase == DigilockerPhase.choosingPayMethod) {
      final rupees = state.selectedModeChargeRupees;
      final modeLabel = state.colorMode == 'color' ? 'color' : 'B&W';
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: 'DigiLocker Print',
          onHome: _endSessionAndGoHome,
          stepLabel: 'Print',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: controller.backFromPrintFlow,
          ),
          body: _ChoiceBody(
            headline: 'How would you like to print?',
            subtitle:
                '$modeLabel print is ₹$rupees per page. Society members can use free $modeLabel pages when available.',
            error: state.error,
            left: _ChoiceCard(
              icon: Icons.phone_android,
              title: 'Use phone number',
              subtitle: 'Check your society free $modeLabel quota first.',
              onPressed: state.phoneBusy ? null : controller.choosePhoneQuota,
            ),
            right: _ChoiceCard(
              icon: Icons.qr_code_2,
              title: 'Pay without phone',
              subtitle: 'Scan UPI and pay ₹$rupees per page.',
              onPressed: state.phoneBusy ? null : controller.choosePayDirect,
            ),
          ),
        ),
      );
    }

    if (state.phase == DigilockerPhase.enteringPhone) {
      final modeLabel = state.colorMode == 'color' ? 'color' : 'B&W';
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: 'DigiLocker Print',
          onHome: _endSessionAndGoHome,
          stepLabel: 'Free quota',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: state.phoneBusy ? null : controller.backFromPrintFlow,
          ),
          footerTrailing: state.otpSent
              ? KioskPrimaryButton(
                  label: state.phoneBusy ? 'Checking…' : 'Verify & continue',
                  loading: state.phoneBusy,
                  onPressed: state.phoneBusy || state.otpDigits.length < 4
                      ? null
                      : () => _verifyOtpAndShowQuota(controller),
                )
              : KioskPrimaryButton(
                  label: state.phoneBusy ? 'Sending…' : 'Send OTP',
                  loading: state.phoneBusy,
                  onPressed: state.phoneBusy || state.phoneDigits.length < 10
                      ? null
                      : controller.requestPrintPhoneOtp,
                ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.otpSent
                      ? 'Enter verification code'
                      : 'Enter mobile number',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.otpSent
                      ? 'We sent a one-time code to +91 ${state.phoneDigits}.'
                      : 'Society numbers with free $modeLabel pages can print without paying.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                if (state.phoneNotice != null &&
                    state.phoneNotice!.trim().isNotEmpty) ...[
                  KioskStatusBanner(
                    message: state.phoneNotice!,
                    tone: KioskBannerTone.warning,
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 12),
                ],
                if (state.error != null && state.error!.trim().isNotEmpty) ...[
                  KioskStatusBanner(
                    message: state.error!,
                    tone: KioskBannerTone.danger,
                    icon: Icons.error_outline,
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: KioskPhoneOtpEntry(
                    key: ValueKey(
                      state.otpSent
                          ? 'digilocker-otp-pad'
                          : 'digilocker-phone-pad',
                    ),
                    value: state.otpSent ? state.otpDigits : state.phoneDigits,
                    mode: state.otpSent
                        ? KioskPhoneOtpMode.otp
                        : KioskPhoneOtpMode.phone,
                    enabled: !state.phoneBusy,
                    onChanged: state.otpSent
                        ? controller.setPrintOtpDigits
                        : controller.setPrintPhoneDigits,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.phase == DigilockerPhase.awaitingPayment) {
      final rupees = (state.amountPaise / 100).round();
      final qrImageUrl = state.qrImageUrl?.trim() ?? '';
      final modeLabel = state.printColorMode == 'color' ? 'color' : 'B&W';
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: 'DigiLocker Print',
          onHome: _endSessionAndGoHome,
          stepLabel: 'Pay',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: controller.backFromPrintFlow,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay to print',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Scan with any UPI app to pay ₹$rupees for this $modeLabel DigiLocker print.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Preview opens after payment is confirmed.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (state.phoneNotice != null &&
                          state.phoneNotice!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        KioskStatusBanner(
                          message: state.phoneNotice!,
                          tone: KioskBannerTone.warning,
                          icon: Icons.info_outline,
                        ),
                      ],
                      if (state.error != null &&
                          state.error!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        KioskStatusBanner(
                          message: state.error!,
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
                  width: 480,
                  height: 480,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
                  ),
                  child: qrImageUrl.isNotEmpty
                      ? Image.network(
                          qrImageUrl,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                            child: Icon(Icons.qr_code_2, size: 64),
                          ),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
      trailing = state.printFailures >= 2
          ? KioskPrimaryButton(
              label: 'Tell staff',
              onPressed: controller.tellStaff,
            )
          : KioskPrimaryButton(
              label: state.phase == DigilockerPhase.printing ? 'Printing…' : 'Print',
              icon: Icons.print,
              loading: state.phase == DigilockerPhase.printing,
              onPressed: state.phase == DigilockerPhase.printing
                  ? null
                  : () => controller.confirmPrint(),
            );
      step = 'Preview';
    } else if (listing) {
      leading = KioskGhostButton(
        label: 'Back',
        icon: Icons.arrow_back,
        onPressed: _goBack,
      );
      step = 'Documents';
    } else if (state.phase == DigilockerPhase.awaitingConsent) {
      leading = KioskGhostButton(
        label: 'Back',
        icon: Icons.arrow_back,
        onPressed: _goBack,
      );
      step = 'Sign in';
    }

    return VisitorSessionPopScope(
      endSessionOnPop: false,
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
            KioskWaitAds(
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
          DigilockerPhase.printResult => KioskPrintResult(
              confirmed: state.printConfirmed,
              detail: state.message,
              autoReturn: state.printConfirmed ? const Duration(seconds: 20) : null,
              onHome: _endSessionAndGoHome,
              onNotReceived: state.printConfirmed ? controller.reportPagesMissing : null,
            ),
          _ => Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KioskDisclaimer(message: KioskDisclaimerCopy.digilocker),
                  const SizedBox(height: 12),
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
                                actionLabel: 'Print',
                                onAction: state.loading
                                    ? null
                                    : () => controller.beginPrintFlow(doc.id),
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

class _ChoiceBody extends StatelessWidget {
  const _ChoiceBody({
    required this.headline,
    required this.subtitle,
    required this.left,
    required this.right,
    this.error,
  });

  final String headline;
  final String subtitle;
  final Widget left;
  final Widget right;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(headline, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 28),
          Expanded(
            child: Row(
              children: [
                Expanded(child: left),
                const SizedBox(width: 20),
                Expanded(child: right),
              ],
            ),
          ),
          if (error != null && error!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            KioskStatusBanner(
              message: error!,
              tone: KioskBannerTone.danger,
              icon: Icons.error_outline,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SkpColors.raised,
      borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
            border: Border.all(color: SkpColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 42, color: SkpColors.accentBright),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SkpColors.muted,
                    ),
              ),
            ],
          ),
        ),
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
      return const KioskWaitAds(message: 'Starting DigiLocker…');
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            KioskStatusBanner(
              message: error!,
              tone: KioskBannerTone.danger,
              icon: Icons.error_outline,
            ),
            const SizedBox(height: 8),
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
