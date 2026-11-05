import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/ads/presentation/kiosk_wait_ads.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_hold.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

/// Shared overlay when an astrology flow is preparing / previewing / printing.
class AstrologyPrintShell extends StatelessWidget {
  const AstrologyPrintShell({
    super.key,
    required this.title,
    required this.print,
    required this.onHome,
    required this.onBackFromPreview,
    required this.onConfirmPrint,
    required this.onTellStaff,
    required this.onClearResult,
    required this.onReportMissing,
    this.onChoosePhoneQuota,
    this.onChoosePayDirect,
    this.onPhoneChanged,
    this.onOtpChanged,
    this.onRequestOtp,
    this.onVerifyOtp,
  });

  final String title;
  final ReportPrintSnapshot print;
  final Future<void> Function() onHome;
  final Future<void> Function() onBackFromPreview;
  final Future<void> Function() onConfirmPrint;
  final Future<void> Function() onTellStaff;
  final VoidCallback onClearResult;
  final Future<void> Function() onReportMissing;
  final Future<void> Function()? onChoosePhoneQuota;
  final Future<void> Function()? onChoosePayDirect;
  final ValueChanged<String>? onPhoneChanged;
  final ValueChanged<String>? onOtpChanged;
  final Future<void> Function()? onRequestOtp;
  final Future<void> Function()? onVerifyOtp;

  @override
  Widget build(BuildContext context) {
    if (print.phase == ReportPrintPhase.choosingPayMethod) {
      final rupees = print.chargeRupees;
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: title,
          onHome: onHome,
          stepLabel: 'Print',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: onBackFromPreview,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How would you like to print?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Color Kundali print is ₹$rupees. Society members can use one free color page.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _PayChoiceCard(
                          icon: Icons.phone_android,
                          title: 'Use phone number',
                          subtitle: 'Check your society free color quota first.',
                          onPressed: print.phoneBusy || onChoosePhoneQuota == null
                              ? null
                              : () => onChoosePhoneQuota!(),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _PayChoiceCard(
                          icon: Icons.qr_code_2,
                          title: 'Pay without phone',
                          subtitle: 'Scan UPI and pay ₹$rupees directly.',
                          onPressed: print.phoneBusy || onChoosePayDirect == null
                              ? null
                              : () => onChoosePayDirect!(),
                        ),
                      ),
                    ],
                  ),
                ),
                if (print.error != null && print.error!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  KioskStatusBanner(
                    message: print.error!,
                    tone: KioskBannerTone.danger,
                    icon: Icons.error_outline,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.enteringPhone) {
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: title,
          onHome: onHome,
          stepLabel: 'Free quota',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: print.phoneBusy ? null : onBackFromPreview,
          ),
          footerTrailing: print.otpSent
              ? KioskPrimaryButton(
                  label: print.phoneBusy ? 'Checking…' : 'Verify & continue',
                  loading: print.phoneBusy,
                  onPressed: print.phoneBusy ||
                          print.otpDigits.length < 4 ||
                          onVerifyOtp == null
                      ? null
                      : onVerifyOtp,
                )
              : KioskPrimaryButton(
                  label: print.phoneBusy ? 'Sending…' : 'Send OTP',
                  loading: print.phoneBusy,
                  onPressed: print.phoneBusy ||
                          print.phoneDigits.length < 10 ||
                          onRequestOtp == null
                      ? null
                      : onRequestOtp,
                ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  print.otpSent ? 'Enter verification code' : 'Enter mobile number',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  print.otpSent
                      ? 'We sent a one-time code to +91 ${print.phoneDigits}.'
                      : 'Society numbers with free color pages can print without paying.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                if (print.phoneNotice != null &&
                    print.phoneNotice!.trim().isNotEmpty) ...[
                  KioskStatusBanner(
                    message: print.phoneNotice!,
                    tone: KioskBannerTone.warning,
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 12),
                ],
                if (print.error != null && print.error!.trim().isNotEmpty) ...[
                  KioskStatusBanner(
                    message: print.error!,
                    tone: KioskBannerTone.danger,
                    icon: Icons.error_outline,
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: KioskPhoneOtpEntry(
                    key: ValueKey(
                      print.otpSent ? 'kundali-otp-pad' : 'kundali-phone-pad',
                    ),
                    value: print.otpSent ? print.otpDigits : print.phoneDigits,
                    mode: print.otpSent
                        ? KioskPhoneOtpMode.otp
                        : KioskPhoneOtpMode.phone,
                    enabled: !print.phoneBusy,
                    onChanged: print.otpSent
                        ? (onOtpChanged ?? (_) {})
                        : (onPhoneChanged ?? (_) {}),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.preparingPreview) {
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: title,
          onHome: onHome,
          stepLabel: 'Print',
          body: const KioskWaitAds(message: 'Preparing print preview…'),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.awaitingPayment) {
      final rupees = (print.amountPaise / 100).round();
      final qrImageUrl = print.qrImageUrl?.trim() ?? '';
      final fallbackUrl = print.checkoutUrl?.trim() ?? '';
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: title,
          onHome: onHome,
          stepLabel: 'Pay',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: onBackFromPreview,
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
                        'Scan with any UPI app to pay ₹$rupees for a color Kundali print.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Printing starts after payment is confirmed.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (print.phoneNotice != null &&
                          print.phoneNotice!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        KioskStatusBanner(
                          message: print.phoneNotice!,
                          tone: KioskBannerTone.warning,
                          icon: Icons.info_outline,
                        ),
                      ],
                      if (print.error != null && print.error!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        KioskStatusBanner(
                          message: print.error!,
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
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.qr_code_2, size: 64),
                          ),
                        )
                      : fallbackUrl.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : QrImageView(
                              data: fallbackUrl,
                              version: QrVersions.auto,
                              backgroundColor: Colors.white,
                            ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.printing) {
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: title,
          onHome: onHome,
          stepLabel: 'Print',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: null,
          ),
          footerTrailing: KioskPrimaryButton(
            label: 'Printing…',
            icon: Icons.print,
            loading: true,
            onPressed: null,
          ),
          body: KioskPrintingProgress(detail: print.message),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.previewing) {
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: title,
          onHome: onHome,
          stepLabel: 'Preview',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: onBackFromPreview,
          ),
          footerTrailing: print.printFailures >= 2
              ? KioskPrimaryButton(
                  label: 'Tell staff',
                  onPressed: onTellStaff,
                )
              : KioskPrimaryButton(
                  label: 'Print',
                  icon: Icons.print,
                  onPressed: onConfirmPrint,
                ),
          body: print.previewBytes == null
              ? const KioskWaitAds(message: 'Preparing…')
              : KioskPdfPreview(
                  title: print.previewTitle ?? title,
                  pdfBytes: print.previewBytes!,
                  error: print.error,
                ),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.printResult) {
      final prepareFailed =
          !print.printConfirmed && print.previewBytes == null;
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: title,
          onHome: onHome,
          stepLabel: 'Print',
          footerLeading: prepareFailed
              ? KioskGhostButton(
                  label: 'Back',
                  icon: Icons.arrow_back,
                  onPressed: () async {
                    onClearResult();
                  },
                )
              : null,
          body: prepareFailed
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: KioskStatusBanner(
                      message: 'Could not prepare print',
                      detail: print.message ?? print.error,
                      tone: KioskBannerTone.danger,
                      icon: Icons.error_outline,
                    ),
                  ),
                )
              : KioskPrintResult(
                  confirmed: print.printConfirmed,
                  detail: print.message,
                  autoReturn:
                      print.printConfirmed ? const Duration(seconds: 20) : null,
                  onHome: () async {
                    onClearResult();
                    await onHome();
                  },
                  onNotReceived:
                      print.printConfirmed ? onReportMissing : null,
                ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _PayChoiceCard extends StatelessWidget {
  const _PayChoiceCard({
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

bool astrologyPrintIsActive(ReportPrintSnapshot print) =>
    print.phase != ReportPrintPhase.idle;

Widget? astrologyPausedShell({
  required WidgetRef ref,
  required ReportPrintSnapshot print,
  required String title,
  required Future<void> Function() onHome,
}) {
  if ((kioskPrintingPaused(ref) || print.paperOut) &&
      print.phase != ReportPrintPhase.printing) {
    return VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: title,
        onHome: onHome,
        body: const KioskPrintingPaused(),
      ),
    );
  }
  return null;
}

void holdSessionForAstrologyPrint(WidgetRef ref, ReportPrintSnapshot print) {
  ref.read(kioskSessionHoldProvider.notifier).set(
        printing: print.phase == ReportPrintPhase.printing ||
            print.phase == ReportPrintPhase.awaitingPayment ||
            print.phase == ReportPrintPhase.choosingPayMethod ||
            print.phase == ReportPrintPhase.enteringPhone ||
            print.phase == ReportPrintPhase.choosingColorMode,
      );
}

/// Result body with an optional danger banner when print/prepare failed.
Widget astrologyResultWithError({
  Key? key,
  required Widget child,
  required String? error,
}) {
  final body = (error == null || error.trim().isEmpty)
      ? child
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: KioskStatusBanner(
                message: error,
                tone: KioskBannerTone.danger,
                icon: Icons.error_outline,
              ),
            ),
            Expanded(child: child),
          ],
        );
  return KeyedSubtree(key: key, child: body);
}
