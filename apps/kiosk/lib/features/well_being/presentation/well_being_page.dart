import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/ads/presentation/kiosk_wait_ads.dart';
import 'package:skp_kiosk/features/service_ratings/domain/service_rating_keys.dart';
import 'package:skp_kiosk/features/service_ratings/presentation/prompt_service_rating.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_hold.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_controller.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_state.dart';
import 'package:skp_kiosk/features/well_being/domain/color_vision_plate.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_mode.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_phase.dart';
import 'package:skp_kiosk/features/well_being/presentation/widgets/color_vision_plate_view.dart';
import 'package:skp_kiosk/features/well_being/presentation/widgets/oxi_monitor_panel.dart';
import 'package:skp_kiosk/features/well_being/presentation/widgets/well_being_marks.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

/// Dual-sensor Well Being flow (USB Serial JSON protocol).
class WellBeingPage extends ConsumerStatefulWidget {
  const WellBeingPage({super.key});

  @override
  ConsumerState<WellBeingPage> createState() => _WellBeingPageState();
}

class _WellBeingPageState extends ConsumerState<WellBeingPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(wellBeingControllerProvider.notifier).startSession();
    });
  }

  Future<void> _promptWellBeingSessionRatingIfComplete() async {
    final phase = ref.read(wellBeingControllerProvider).phase;
    final complete = phase == WellBeingPhase.oxiComplete ||
        phase == WellBeingPhase.tempComplete ||
        phase == WellBeingPhase.colorVisionComplete;
    if (!complete || !mounted) {
      return;
    }
    await promptServiceRatingIfNeeded(
      context,
      ref,
      family: ServiceRatingKeys.familyWellBeing,
      serviceKey: ServiceRatingKeys.wellBeingSession,
    );
  }

  Future<void> _endSession() async {
    await _promptWellBeingSessionRatingIfComplete();
    if (!mounted) return;
    await ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  Future<void> _doneAfterMeasurement() async {
    await _promptWellBeingSessionRatingIfComplete();
    if (!mounted) return;
    await ref.read(wellBeingControllerProvider.notifier).returnToHub();
  }

  Future<void> _verifyOtpAndShowQuota(WellBeingController controller) async {
    final summary = await controller.verifyPrintPhoneOtp();
    if (!mounted || summary == null) return;

    await showKioskPrintQuotaDialog(
      context: context,
      remainingLabel: summary.remainingLabel,
      costLine: summary.printCostLine,
      notice: summary.freeEligible ? null : summary.message,
    );
    if (!mounted) return;
    await controller.continueAfterQuotaSummary(summary);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wellBeingControllerProvider);
    final controller = ref.read(wellBeingControllerProvider.notifier);
    final print = state.print;

    ref.listen(wellBeingControllerProvider, (previous, next) {
      final phase = next.print.phase;
      ref.read(kioskSessionHoldProvider.notifier).set(
            printing: phase == ReportPrintPhase.printing ||
                phase == ReportPrintPhase.awaitingPayment ||
                phase == ReportPrintPhase.choosingPrintOptions ||
                phase == ReportPrintPhase.enteringPhone ||
                phase == ReportPrintPhase.preparingPreview ||
                phase == ReportPrintPhase.previewing,
          );
    });

    if ((kioskPrintingPaused(ref) || print.paperOut) &&
        print.phase != ReportPrintPhase.printing) {
      return VisitorSessionPopScope(
        child: KioskShell(
          title: 'Well Being',
          onHome: _endSession,
          body: const KioskPrintingPaused(),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.choosingPrintOptions) {
      return VisitorSessionPopScope(
        child: KioskShell(
          title: 'Well Being',
          onHome: _endSession,
          stepLabel: 'Print options',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: controller.backFromPrintFlow,
          ),
          body: KioskPrintOptionsBody(
            colorMode: print.colorMode == 'color' ? 'color' : 'bw',
            bwChargeRupees: print.bwChargeRupees,
            colorChargeRupees: print.colorChargeRupees,
            documentHint: 'Choose how this health report should print.',
            error: print.error,
            busy: print.phoneBusy,
            onColorModeChanged: controller.setColorMode,
            onChoosePhone: controller.choosePhoneQuota,
            onChoosePay: controller.choosePayDirect,
            onContinueFree: controller.continueFreePrint,
          ),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.enteringPhone) {
      final modeLabel = print.colorMode == 'color' ? 'color' : 'B&W';
      return VisitorSessionPopScope(
        child: KioskShell(
          title: 'Well Being',
          onHome: _endSession,
          stepLabel: 'Free quota',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: print.phoneBusy ? null : controller.backFromPrintFlow,
          ),
          footerTrailing: print.otpSent
              ? KioskPrimaryButton(
                  label: print.phoneBusy ? 'Checking…' : 'Verify & continue',
                  loading: print.phoneBusy,
                  onPressed: print.phoneBusy || print.otpDigits.length < 4
                      ? null
                      : () => _verifyOtpAndShowQuota(controller),
                )
              : KioskPrimaryButton(
                  label: print.phoneBusy ? 'Sending…' : 'Send OTP',
                  loading: print.phoneBusy,
                  onPressed: print.phoneBusy || print.phoneDigits.length < 10
                      ? null
                      : controller.requestPrintPhoneOtp,
                ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  print.otpSent
                      ? 'Enter verification code'
                      : 'Enter mobile number',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  print.otpSent
                      ? 'We sent a one-time code to +91 ${print.phoneDigits}.'
                      : 'Society numbers with free $modeLabel pages can print without paying.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
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
                      print.otpSent
                          ? 'wellbeing-otp-pad'
                          : 'wellbeing-phone-pad',
                    ),
                    value: print.otpSent ? print.otpDigits : print.phoneDigits,
                    mode: print.otpSent
                        ? KioskPhoneOtpMode.otp
                        : KioskPhoneOtpMode.phone,
                    enabled: !print.phoneBusy,
                    onChanged: print.otpSent
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

    if (print.phase == ReportPrintPhase.preparingPreview) {
      return VisitorSessionPopScope(
        child: KioskShell(
          title: 'Well Being',
          onHome: _endSession,
          stepLabel: 'Print',
          body: const KioskWaitAds(message: 'Preparing health report…'),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.awaitingPayment) {
      final rupees = (print.amountPaise / 100).round();
      final modeLabel = print.colorMode == 'color' ? 'color' : 'B&W';
      final qrImageUrl = print.qrImageUrl?.trim() ?? '';
      final fallbackUrl = print.checkoutUrl?.trim() ?? '';
      return VisitorSessionPopScope(
        child: KioskShell(
          title: 'Well Being',
          onHome: _endSession,
          stepLabel: 'Pay',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: controller.backFromPrintFlow,
          ),
          body: KioskUpiPayPanel(
            detail:
                'Scan with any UPI app to pay ₹$rupees for a $modeLabel health report.',
            followUp: 'Printing starts after payment is confirmed.',
            qrImageUrl: qrImageUrl,
            fallbackUrl: fallbackUrl,
            notice: print.phoneNotice,
            error: print.error,
          ),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.printing) {
      return VisitorSessionPopScope(
        child: KioskShell(
          title: 'Well Being',
          onHome: _endSession,
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
        child: KioskShell(
          title: 'Well Being',
          onHome: _endSession,
          stepLabel: 'Preview',
          footerLeading: KioskGhostButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: () => controller.cancelPrintPreview(),
          ),
          footerTrailing: print.printFailures >= 2
              ? KioskPrimaryButton(
                  label: 'Tell staff',
                  onPressed: controller.tellStaffPrint,
                )
              : KioskPrimaryButton(
                  label: 'Print',
                  icon: Icons.print,
                  onPressed: controller.confirmPrint,
                ),
          body: print.previewBytes == null
              ? const KioskWaitAds(message: 'Preparing…')
              : KioskPdfPreview(
                  title: print.previewTitle ?? 'Health Report',
                  pdfBytes: print.previewBytes!,
                  error: print.error,
                  message: print.message,
                ),
        ),
      );
    }

    if (print.phase == ReportPrintPhase.printResult) {
      return VisitorSessionPopScope(
        child: KioskShell(
          title: 'Well Being',
          onHome: _endSession,
          stepLabel: 'Print',
          body: KioskPrintResult(
            confirmed: print.printConfirmed,
            detail: print.message,
            autoReturn: print.printConfirmed ? const Duration(seconds: 20) : null,
            onHome: () async {
              controller.clearPrintResult();
              await controller.returnToHub();
            },
            onNotReceived:
                print.printConfirmed ? controller.reportPrintPagesMissing : null,
            ratingServiceKey: ServiceRatingKeys.wellBeingPrint,
          ),
        ),
      );
    }

    final showBack = state.phase != WellBeingPhase.choose &&
        (state.isColorVisionFlow ||
            state.connectionStatus != SerialConnectionStatus.connecting);
    final complete = state.isMeasurementComplete;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentStep = switch (state.phase) {
      WellBeingPhase.choose => 1,
      WellBeingPhase.oxiIdle ||
      WellBeingPhase.oxiMeasuring ||
      WellBeingPhase.oxiCancelled ||
      WellBeingPhase.tempIdle ||
      WellBeingPhase.tempMeasuring ||
      WellBeingPhase.colorVisionIntro ||
      WellBeingPhase.colorVisionTesting =>
        2,
      WellBeingPhase.oxiComplete ||
      WellBeingPhase.tempComplete ||
      WellBeingPhase.colorVisionComplete =>
        3,
    };

    return VisitorSessionPopScope(
      child: KioskShell(
        titleWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2E1222) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF6B1D45) : const Color(0xFFFCE7F3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💓', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Health Measurement',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                ),
              ),
            ],
          ),
        ),
        onHome: _endSession,
        headerExtra: kDebugMode
            ? IconButton(
                tooltip: 'Serial Debug',
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.serialDebug);
                },
                icon: const Icon(Icons.bug_report_outlined, color: SkpColors.muted),
              )
            : null,
        footerCenter: _WellBeingStepIndicator(step: currentStep),
        footerLeading: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1738) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF4A3474) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: showBack ? () => controller.returnToHub() : _endSession,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Back',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        footerTrailing: complete
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KioskGhostButton(
                    label: 'Done',
                    onPressed: _doneAfterMeasurement,
                  ),
                  const SizedBox(width: 12),
                  KioskPrimaryButton(
                    label: 'Print',
                    icon: Icons.print,
                    expand: false,
                    onPressed: controller.preparePrint,
                  ),
                ],
              )
            : const _PartnerPill(),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(32, 10, 32, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.phase != WellBeingPhase.choose &&
                  !state.isColorVisionFlow &&
                  (state.connectionStatus == SerialConnectionStatus.error ||
                      state.connectionStatus == SerialConnectionStatus.disconnected))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ConnectionBanner(
                    label: state.connectionLabel,
                    portName: state.portName,
                    status: state.connectionStatus,
                    activeMode: state.activeMode,
                    fingerDetected: state.fingerDetected,
                    objectDetected: state.objectDetected,
                    error: state.lastError,
                    onRetry: () => controller.retryConnect(),
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: switch (state.phase) {
                    WellBeingPhase.choose => _ChooseView(
                        key: const ValueKey('choose'),
                        connected: state.isConnected,
                        onOxygen: () => controller.startOxygen(),
                        onTemperature: () => controller.startTemperature(),
                        onColorVision: () => controller.startColorVision(),
                      ),
                    WellBeingPhase.oxiIdle => _OxiIdleView(
                        key: const ValueKey('oxiIdle'),
                        connected: state.isConnected,
                      ),
                    WellBeingPhase.oxiMeasuring => _OxiMeasuringView(
                        key: const ValueKey('oxiMeasuring'),
                        state: state,
                      ),
                    WellBeingPhase.oxiCancelled => const _OxiCancelledView(
                        key: ValueKey('oxiCancelled'),
                      ),
                    WellBeingPhase.oxiComplete => _OxiCompleteView(
                        key: const ValueKey('oxiComplete'),
                        state: state,
                      ),
                    WellBeingPhase.tempIdle => _TempIdleView(
                        key: const ValueKey('tempIdle'),
                        connected: state.isConnected,
                      ),
                    WellBeingPhase.tempMeasuring => _TempMeasuringView(
                        key: const ValueKey('tempMeasuring'),
                        state: state,
                      ),
                    WellBeingPhase.tempComplete => _TempCompleteView(
                        key: const ValueKey('tempComplete'),
                        state: state,
                      ),
                    WellBeingPhase.colorVisionIntro => _ColorVisionIntroView(
                        key: const ValueKey('colorVisionIntro'),
                        onStart: controller.beginColorVisionTest,
                      ),
                    WellBeingPhase.colorVisionTesting => _ColorVisionTestingView(
                        key: ValueKey('cv-${state.colorVisionPlateIndex}'),
                        state: state,
                        onAnswer: controller.answerColorVisionPlate,
                      ),
                    WellBeingPhase.colorVisionComplete => _ColorVisionCompleteView(
                        key: const ValueKey('colorVisionComplete'),
                        state: state,
                      ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.label,
    required this.status,
    required this.activeMode,
    required this.fingerDetected,
    required this.objectDetected,
    this.portName,
    this.error,
    this.onRetry,
  });

  final String label;
  final SerialConnectionStatus status;
  final WellBeingMode activeMode;
  final bool fingerDetected;
  final bool objectDetected;
  final String? portName;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      SerialConnectionStatus.connected =>
        fingerDetected || objectDetected
            ? KioskBannerTone.success
            : KioskBannerTone.info,
      SerialConnectionStatus.connecting ||
      SerialConnectionStatus.reconnecting =>
        KioskBannerTone.warning,
      SerialConnectionStatus.error => KioskBannerTone.danger,
      SerialConnectionStatus.disconnected => KioskBannerTone.warning,
    };

    final detailLabel = !status.isConnected
        ? label
        : switch (activeMode) {
            WellBeingMode.oxi =>
              fingerDetected ? 'Finger detected' : 'No finger detected',
            WellBeingMode.temp =>
              objectDetected ? 'Forehead detected' : 'No forehead detected',
            WellBeingMode.colorVision => 'Color vision screening',
            WellBeingMode.none => 'Ready',
          };

    return KioskStatusBanner(
      message: detailLabel,
      detail: [label, ?portName, if (error != null && status == SerialConnectionStatus.error) error!].join(' · '),
      tone: tone,
      icon: status.isConnected
          ? switch (activeMode) {
              WellBeingMode.temp =>
                objectDetected ? Icons.thermostat : Icons.sensors,
              WellBeingMode.oxi => fingerDetected ? Icons.back_hand : Icons.sensors,
              WellBeingMode.colorVision => Icons.visibility_outlined,
              WellBeingMode.none => Icons.favorite_outline,
            }
          : Icons.sensors_off,
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }
}

extension on SerialConnectionStatus {
  bool get isConnected => this == SerialConnectionStatus.connected;
}

class _ChooseView extends StatelessWidget {
  const _ChooseView({
    super.key,
    required this.connected,
    required this.onOxygen,
    required this.onTemperature,
    required this.onColorVision,
  });

  final bool connected;
  final VoidCallback onOxygen;
  final VoidCallback onTemperature;
  final VoidCallback onColorVision;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Header + 3D Health Terminal Illustration
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Check Your ',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFE11D48), Color(0xFFF43F5E), Color(0xFFEC4899)],
                          ).createShader(bounds),
                          child: const Text(
                            'Health',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quick, safe and non-invasive health measurements.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Glowing Underline Accent Bar
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF43F5E).withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 3 Feature highlight pills
                    Row(
                      children: [
                        _FeaturePill(
                          icon: Icons.bolt_rounded,
                          iconColor: const Color(0xFFD946EF),
                          title: 'Quick & Easy',
                          subtitle: 'Get results in seconds',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _FeaturePill(
                          icon: Icons.shield_outlined,
                          iconColor: const Color(0xFFE11D48),
                          title: 'Safe & Contactless',
                          subtitle: 'Hygienic and user-friendly',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _FeaturePill(
                          icon: Icons.bar_chart_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'Instant Results',
                          subtitle: 'On-screen measurement',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const HealthHeroIllustration(),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Privacy Banner (Matching Reference Image)
          const _WellBeingPrivacyBanner(),

          const SizedBox(height: 12),

          // 3. Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 32, height: 1.5, color: const Color(0xFFF43F5E)),
              const SizedBox(width: 10),
              Text(
                'Choose a Health Check',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 10),
              Container(width: 32, height: 1.5, color: const Color(0xFFF43F5E)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Select a vital check or color vision screening. Sensor tests run one at a time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 12),

          // 4. Measurement Cards
          Row(
            children: [
              Expanded(
                child: _MeasurementCard(
                  title: 'Blood Oxygen',
                  subtitle: 'Measure your oxygen level (SpO2)\nand heart rate with your fingertip.',
                  graphic: const Oximeter3DGraphic(size: 88),
                  accentColor: const Color(0xFF0284C7),
                  cardGradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF131D33), Color(0xFF172554)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
                          stops: [0.35, 0.75, 1.0],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderColor: isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD),
                  shadowColor: const Color(0xFF0284C7),
                  tags: const [
                    (icon: '🫁', label: 'SpO2 (Oxygen Level)'),
                    (icon: '💓', label: 'Heart Rate'),
                  ],
                  onTap: onOxygen,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MeasurementCard(
                  title: 'Temperature',
                  subtitle: 'Measure your body temperature\nquickly and contactlessly with sensor.',
                  graphic: const Thermometer3DGraphic(size: 88),
                  accentColor: const Color(0xFFE11D48),
                  cardGradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF241523), Color(0xFF3B1832)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFFDF2F8), Color(0xFFFCE7F3)],
                          stops: [0.35, 0.75, 1.0],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderColor: isDark ? const Color(0xFF9F1239) : const Color(0xFFFBCFE8),
                  shadowColor: const Color(0xFFE11D48),
                  onTap: onTemperature,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _ColorVisionHubCard(
            isDark: isDark,
            onTap: onColorVision,
          ),

          const SizedBox(height: 10),

          // 5. Medical Disclaimer
          const _MedicalDisclaimer(),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1738) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF4A3474) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WellBeingPrivacyBanner extends StatelessWidget {
  const _WellBeingPrivacyBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF059669).withValues(alpha: 0.45) : const Color(0xFFA7F3D0),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF059669),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'We do not save health readings. Measurements stay on this screen only and are cleared when you leave.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({
    required this.title,
    required this.subtitle,
    required this.graphic,
    required this.accentColor,
    required this.cardGradient,
    required this.borderColor,
    required this.shadowColor,
    required this.onTap,
    required this.isDark,
    this.tags,
  });

  final String title;
  final String subtitle;
  final Widget graphic;
  final Color accentColor;
  final Gradient cardGradient;
  final Color borderColor;
  final Color shadowColor;
  final VoidCallback onTap;
  final bool isDark;
  final List<({String icon, String label})>? tags;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: cardGradient,
        border: Border.all(
          color: borderColor.withValues(alpha: isDark ? 0.7 : 0.85),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: accentColor.withValues(alpha: 0.12),
          highlightColor: accentColor.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                graphic,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                      if (tags != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final tag in tags!)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(tag.icon, style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 5),
                                    Text(
                                      tag.label,
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: Border.all(
                      color: accentColor.withValues(alpha: isDark ? 0.8 : 0.85),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.20),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WellBeingStepIndicator extends StatelessWidget {
  const _WellBeingStepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepNode(number: 1, label: 'Choose', isCurrent: step == 1, isPast: step > 1, isDark: isDark),
        Container(
          width: 32,
          height: 1.5,
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          margin: const EdgeInsets.symmetric(horizontal: 10),
        ),
        _StepNode(number: 2, label: 'Measure', isCurrent: step == 2, isPast: step > 2, isDark: isDark),
        Container(
          width: 32,
          height: 1.5,
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          margin: const EdgeInsets.symmetric(horizontal: 10),
        ),
        _StepNode(number: 3, label: 'Results', isCurrent: step == 3, isPast: false, isDark: isDark),
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.number,
    required this.label,
    required this.isCurrent,
    required this.isPast,
    required this.isDark,
  });

  final int number;
  final String label;
  final bool isCurrent;
  final bool isPast;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent
                ? const Color(0xFFE11D48)
                : (isPast ? const Color(0xFF10B981) : Colors.transparent),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xFFE11D48)
                  : (isPast
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
              width: 1.6,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isCurrent || isPast
                    ? Colors.white
                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            color: isCurrent
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }
}

class _PartnerPill extends StatelessWidget {
  const _PartnerPill();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1738) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF4A3474) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🚀', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Empowering Businesses with ',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                const TextSpan(
                  text: 'Smart IT Solutions',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE11D48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OxiIdleView extends StatelessWidget {
  const _OxiIdleView({super.key, required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _InstructionHero(
            assetPath: 'assets/well_being/place_finger_on_sensor.jpg',
            headline: connected
                ? 'Place your finger on the sensor'
                : 'Connect the sensor to begin',
            subtitle: connected
                ? 'Measurement starts automatically once your finger is detected.'
                : 'Plug in the USB sensor, then place your fingertip on the window.',
            pulse: connected,
          ),
          const SizedBox(height: 20),
          const _TipPanel(
            title: 'How to place your finger',
            tips: [
              'Rest your fingertip flat over the sensor window.',
              'Apply light, steady pressure — do not press hard.',
              'Keep your hand relaxed and still.',
            ],
          ),
        ],
      ),
    );
  }
}

class _OxiMeasuringView extends StatelessWidget {
  const _OxiMeasuringView({super.key, required this.state});

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            'Keep your finger still',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            state.statusMessage ??
                'Do not move or press too hard during measurement.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 16),
          OxiMonitorPanel(state: state),
        ],
      ),
    );
  }
}

class _OxiCancelledView extends StatelessWidget {
  const _OxiCancelledView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.highlight_off, size: 72, color: SkpColors.danger),
        const SizedBox(height: 16),
        Text(
          'Finger Removed',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: SkpColors.danger),
        ),
        const SizedBox(height: 8),
        Text(
          'Measurement cancelled. Returning to options…',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
        ),
      ],
    );
  }
}

class _OxiCompleteView extends StatelessWidget {
  const _OxiCompleteView({super.key, required this.state});

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 56,
            color: SkpColors.accentBright,
          ),
          const SizedBox(height: 10),
          Text(
            'Measurement Complete',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'You may now remove your finger',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 14),
          OxiMonitorPanel(state: state, complete: true),
          const SizedBox(height: 14),
          const _ReferenceCard(
            lines: [
              'Heart rate (adult): 60 – 100 BPM',
              'Blood oxygen: 95 – 100%',
            ],
          ),
          const SizedBox(height: 12),
          const _MedicalDisclaimer(),
        ],
      ),
    );
  }
}

class _TempIdleView extends StatelessWidget {
  const _TempIdleView({super.key, required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _InstructionHero(
            assetPath: 'assets/well_being/hold_forehead_near_sensor.jpg',
            headline: connected
                ? 'Hold your forehead near the sensor'
                : 'Connect the sensor to begin',
            subtitle: connected
                ? 'Measurement starts automatically once your forehead is detected.'
                : 'Plug in the USB sensor, then hold your forehead near the lens.',
            pulse: connected,
          ),
          const SizedBox(height: 20),
          const _TipPanel(
            title: 'How to take your temperature',
            tips: [
              'Hold your forehead 1–2 cm in front of the sensor lens.',
              'Keep hair, hats, and glasses out of the way.',
              'Stay still until the countdown begins.',
            ],
          ),
        ],
      ),
    );
  }
}

class _InstructionHero extends StatefulWidget {
  const _InstructionHero({
    required this.assetPath,
    required this.headline,
    required this.subtitle,
    required this.pulse,
  });

  final String assetPath;
  final String headline;
  final String subtitle;
  final bool pulse;

  @override
  State<_InstructionHero> createState() => _InstructionHeroState();
}

class _InstructionHeroState extends State<_InstructionHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _syncPulse(widget.pulse);
  }

  @override
  void didUpdateWidget(covariant _InstructionHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse) {
      _syncPulse(widget.pulse);
    }
  }

  void _syncPulse(bool enabled) {
    if (enabled) {
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true);
      }
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = widget.pulse ? _pulse.value : 0.0;
            final scale = 1.0 + (t * 0.03);
            final opacity = 0.92 + (t * 0.08);
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: child,
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
            child: Image.asset(
              widget.assetPath,
              height: 300,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.headline,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
        ),
      ],
    );
  }
}

class _TipPanel extends StatelessWidget {
  const _TipPanel({required this.title, required this.tips});

  final String title;
  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SkpColors.panel,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        border: Border.all(color: SkpColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.accentBright),
          ),
          const SizedBox(height: 12),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: SkpColors.gold)),
                  Expanded(child: Text(tip, style: theme.textTheme.bodyLarge)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TempMeasuringView extends StatelessWidget {
  const _TempMeasuringView({super.key, required this.state});

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Icon(Icons.thermostat, size: 72, color: SkpColors.accentBright),
          const SizedBox(height: 12),
          Text('Temperature', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            state.statusMessage ?? 'Hold your forehead still',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 24),
          _TimerRing(seconds: state.secondsRemaining, progress: state.measureProgress),
        ],
      ),
    );
  }
}

class _TempCompleteView extends StatelessWidget {
  const _TempCompleteView({super.key, required this.state});

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    final c = state.finalTempC;
    final f = state.finalTempF;
    return SingleChildScrollView(
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: SkpColors.accentBright),
          const SizedBox(height: 12),
          Text('Temperature Captured', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          _MetricCard(
            title: 'Temperature',
            value: f == null ? '—' : f.toStringAsFixed(1),
            unit: '°F',
            caption: state.temperatureInterpretation,
          ),
          if (c != null) ...[
            const SizedBox(height: 8),
            Text(
              '${c.toStringAsFixed(1)} °C',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: SkpColors.muted),
            ),
          ],
          const SizedBox(height: 16),
          const _ReferenceCard(
            lines: ['Typical body temperature: ~97 – 99 °F (36.1 – 37.2 °C)'],
          ),
          const SizedBox(height: 12),
          const _MedicalDisclaimer(),
        ],
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.seconds, required this.progress});

  final int seconds;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 12,
              backgroundColor: SkpColors.accent.withValues(alpha: 0.2),
              color: SkpColors.accentBright,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: SkpColors.accentBright,
                    ),
              ),
              Text('SECONDS', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    this.caption,
    this.accent = const Color(0xFFE11D48),
  });

  final String title;
  final String value;
  final String unit;
  final String? caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1738) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF4A3474) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                caption!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        border: Border.all(color: SkpColors.line),
        color: SkpColors.raised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reference ranges',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 8),
          for (final line in lines) Text(line, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _MedicalDisclaimer extends StatelessWidget {
  const _MedicalDisclaimer();

  static const _copy =
      'For general wellness and informational use only. This kiosk is not a medical device '
      'and does not provide medical diagnosis, treatment, or clinical monitoring. Readings may be '
      'inaccurate and are not a substitute for professional medical advice. '
      'If you have health concerns, consult a qualified clinician. In an emergency, contact local '
      'emergency services immediately.';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0284C7)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _copy,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorVisionGraphic extends StatelessWidget {
  const _ColorVisionGraphic({this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Color(0xFFEF4444),
              Color(0xFFF59E0B),
              Color(0xFF22C55E),
              Color(0xFF06B6D4),
              Color(0xFF8B5CF6),
              Color(0xFFEF4444),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF059669).withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: size * 0.56,
            height: size * 0.56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              Icons.visibility_rounded,
              size: size * 0.3,
              color: const Color(0xFF047857),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorVisionHubCard extends StatefulWidget {
  const _ColorVisionHubCard({
    required this.isDark,
    required this.onTap,
  });

  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_ColorVisionHubCard> createState() => _ColorVisionHubCardState();
}

class _ColorVisionHubCardState extends State<_ColorVisionHubCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF0F241C), Color(0xFF14532D), Color(0xFF0B1F17)]
                  : const [Color(0xFFFFFFFF), Color(0xFFECFDF5), Color(0xFFD1FAE5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(
              color: (isDark ? const Color(0xFF166534) : const Color(0xFF6EE7B7))
                  .withValues(alpha: 0.55 + t * 0.35),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.1 + t * 0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: const Color(0xFF059669).withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            child: Row(
              children: [
                ColorVisionPlateView(
                  plate: ColorVisionBattery.plates.first,
                  size: 92,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'NEW · NO SENSOR NEEDED',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Color Vision Test',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Short red–green screening with 10 original dotted plates. Get an instant result you can print.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _CvChip(
                            icon: Icons.timer_outlined,
                            label: '~2 min',
                            isDark: isDark,
                          ),
                          _CvChip(
                            icon: Icons.grid_view_rounded,
                            label: '10 plates',
                            isDark: isDark,
                          ),
                          _CvChip(
                            icon: Icons.print_outlined,
                            label: 'Printable',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF059669)
                        .withValues(alpha: isDark ? 0.28 : 0.14),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CvChip extends StatelessWidget {
  const _CvChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1F17) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF166534) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF059669)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorVisionIntroView extends StatelessWidget {
  const _ColorVisionIntroView({
    super.key,
    required this.onStart,
  });

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0xFF0B1F17), Color(0xFF14532D)]
                        : const [Color(0xFFF0FDF4), Color(0xFFD1FAE5)],
                  ),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF166534)
                        : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -40,
                      top: -30,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.18,
                          child: _ColorVisionGraphic(size: 220),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.55),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF059669)
                                      .withValues(alpha: 0.2),
                                  blurRadius: 28,
                                ),
                              ],
                            ),
                            child: ColorVisionPlateView(
                              plate: ColorVisionBattery.plates.first,
                              size: math.min(280, constraints.maxHeight * 0.48),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Sample screening plate',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Color Vision Screening',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A quick wellness screen for red–green color difficulty.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Column(
                        children: [
                          _CvStepTile(
                            index: 1,
                            title: 'View each dotted plate',
                            body: 'Figures are made of colored dots on a matching background.',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          _CvStepTile(
                            index: 2,
                            title: 'Tap what you see',
                            body: 'Choose a number, Nothing, or Unclear — go with your first clear reading.',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          _CvStepTile(
                            index: 3,
                            title: 'Get a printable result',
                            body: 'Screening only — not a clinical diagnosis or Ishihara exam.',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: KioskPrimaryButton(
                        label: 'Start screening',
                        icon: Icons.play_arrow_rounded,
                        onPressed: onStart,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CvStepTile extends StatelessWidget {
  const _CvStepTile({
    required this.index,
    required this.title,
    required this.body,
    required this.isDark,
  });

  final int index;
  final String title;
  final String body;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark ? const Color(0xFF10241C) : Colors.white,
          border: Border.all(
            color: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF059669).withValues(alpha: isDark ? 0.12 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF059669).withValues(alpha: isDark ? 0.28 : 0.12),
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorVisionTestingView extends StatelessWidget {
  const _ColorVisionTestingView({
    super.key,
    required this.state,
    required this.onAnswer,
  });

  final WellBeingUiState state;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final plate = state.currentColorVisionPlate;
    if (plate == null) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = state.colorVisionSessionPlates.isEmpty
        ? ColorVisionBattery.plates.length
        : state.colorVisionSessionPlates.length;
    final index = state.colorVisionPlateIndex;

    return Column(
      children: [
        _CvProgressHeader(
          index: index,
          total: total,
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? const [Color(0xFF0F172A), Color(0xFF10241C)]
                          : const [Color(0xFFF8FAFC), Color(0xFFECFDF5)],
                    ),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFD1FAE5),
                    ),
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.96, end: 1).animate(
                              animation,
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        key: ValueKey(plate.id),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: isDark ? 0.22 : 0.14),
                              blurRadius: 36,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final side = math.min(
                              math.min(c.maxWidth, c.maxHeight) * 0.92,
                              420.0,
                            );
                            return ColorVisionPlateView(
                              plate: plate,
                              size: side,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: isDark ? const Color(0xFF10241C) : Colors.white,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF166534)
                          : const Color(0xFFBBF7D0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669)
                            .withValues(alpha: isDark ? 0.14 : 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'What do you see?',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap your best match. Trust your first clear impression.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Column(
                          children: [
                            for (var i = 0; i < plate.options.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              Expanded(
                                child: _CvAnswerButton(
                                  label: plate.options[i],
                                  isDark: isDark,
                                  onTap: () => onAnswer(plate.options[i]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CvProgressHeader extends StatelessWidget {
  const _CvProgressHeader({
    required this.index,
    required this.total,
    required this.isDark,
  });

  final int index;
  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Plate ${index + 1} / $total',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Color vision screening',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: i <= index
                        ? const Color(0xFF059669)
                        : (isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CvAnswerButton extends StatefulWidget {
  const _CvAnswerButton({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_CvAnswerButton> createState() => _CvAnswerButtonState();
}

class _CvAnswerButtonState extends State<_CvAnswerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: isDark ? const Color(0xFF0B1F17) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(18),
          splashColor: const Color(0xFF059669).withValues(alpha: 0.16),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF166534) : const Color(0xFF86EFAC),
                width: 1.4,
              ),
            ),
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: isDark ? Colors.white : const Color(0xFF064E3B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorVisionCompleteView extends StatelessWidget {
  const _ColorVisionCompleteView({
    super.key,
    required this.state,
  });

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    final result = state.colorVisionResult;
    if (result == null) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = switch (result.outcome) {
      ColorVisionOutcome.normal => const Color(0xFF059669),
      ColorVisionOutcome.possibleDeficiency => const Color(0xFFD97706),
      ColorVisionOutcome.inconclusive => const Color(0xFF64748B),
    };
    final icon = switch (result.outcome) {
      ColorVisionOutcome.normal => Icons.check_circle_rounded,
      ColorVisionOutcome.possibleDeficiency => Icons.warning_amber_rounded,
      ColorVisionOutcome.inconclusive => Icons.help_outline_rounded,
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: isDark ? 0.22 : 0.1),
                      isDark ? const Color(0xFF0F172A) : Colors.white,
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: isDark ? 0.28 : 0.14),
                      ),
                      child: Icon(icon, size: 40, color: accent),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      result.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'Correct plates',
                            value: '${result.correctCount}',
                            unit: '/ ${result.totalPlates}',
                            caption: result.scoreLabel,
                            accent: accent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E1738)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF4A3474)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Screening outcome',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  switch (result.outcome) {
                                    ColorVisionOutcome.normal => 'Normal',
                                    ColorVisionOutcome.possibleDeficiency =>
                                      'Review advised',
                                    ColorVisionOutcome.inconclusive =>
                                      'Inconclusive',
                                  },
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Wellness screen only',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      result.summary,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        result.advice,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Use Print below for a takeaway copy of this screening.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
