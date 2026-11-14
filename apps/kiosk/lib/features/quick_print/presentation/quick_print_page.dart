import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(quickPrintControllerProvider.notifier).start());
  }

  Future<void> _endSession() async {
    await ref.read(quickPrintControllerProvider.notifier).abandonRetry();
    await ref.read(kioskSessionControllerProvider.notifier).endVisitorSession(attract: false);
  }

  Future<void> _goBack() async {
    await ref.read(quickPrintControllerProvider.notifier).reset();
    if (!mounted) return;
    Navigator.of(context).pop();
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
    if ((kioskPrintingPaused(ref) || state.paperOut) &&
        state.phase != QuickPrintPhase.printing) {
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: 'QR Print',
          onHome: _endSession,
          body: const KioskPrintingPaused(),
        ),
      );
    }

    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divider = isDark ? const Color(0xFF2E1C59) : const Color(0xFFE2EBF5);

    Widget? leading;
    Widget? trailing;
    String? step;
    if (state.phase == QuickPrintPhase.waiting ||
        state.phase == QuickPrintPhase.starting ||
        state.phase == QuickPrintPhase.error) {
      leading = KioskGhostButton(
        label: 'Back',
        icon: Icons.arrow_back,
        onPressed: _goBack,
      );
      if (state.phase == QuickPrintPhase.error) {
        trailing = KioskPrimaryButton(
          label: 'Try again',
          onPressed: () => controller.start(),
        );
      } else {
        trailing = _QuickPrintBrandingFooter(colors: colors, divider: divider);
      }
      step = 'Scan';
    } else if (previewing) {
      leading = KioskGhostButton(
        label: 'Back',
        icon: Icons.arrow_back,
        onPressed: state.phase == QuickPrintPhase.printing ? null : controller.backToDocuments,
      );
      trailing = state.printFailures >= 2
          ? KioskPrimaryButton(
              label: 'Tell staff',
              onPressed: controller.tellStaff,
            )
          : KioskPrimaryButton(
              label: state.phase == QuickPrintPhase.printing ? 'Printing…' : 'Print',
              icon: Icons.print,
              loading: state.phase == QuickPrintPhase.printing,
              onPressed: state.phase == QuickPrintPhase.printing ? null : controller.confirmPrint,
            );
      step = 'Preview';
    } else if (listing) {
      leading = null;
      trailing = KioskGhostButton(label: 'Cancel', onPressed: _endSession);
      step = 'Documents';
    }

    return VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: 'Print Documents',
        titleIcon: Icons.print_rounded,
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
          QuickPrintPhase.printing => KioskPrintingProgress(detail: state.message),
          QuickPrintPhase.previewing when state.previewBytes != null =>
            KioskPdfPreview(
              title: state.previewDoc?.fileName ?? 'Document',
              pdfBytes: state.previewBytes!,
              error: state.error,
              message: state.message,
            ),
          QuickPrintPhase.printResult => KioskPrintResult(
              confirmed: state.printed,
              detail: state.message,
              autoReturn: state.printed && !state.hasUnprintedDocuments
                  ? const Duration(seconds: 20)
                  : null,
              onHome: _endSession,
              onContinue: state.printed && state.hasUnprintedDocuments
                  ? controller.continueToDocuments
                  : null,
              onNotReceived: state.printed ? controller.reportPagesMissing : null,
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
                                  '${doc.pageCount} page(s) · ${state.claim?.printColorLabel ?? 'B/W'}'
                                  '${doc.printed ? ' · Printed' : ''}',
                              actionLabel: doc.printed ? 'Printed' : 'Preview',
                              onAction: state.loading || doc.printed
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
              expiresAt: state.session?.expiresAt,
              error: state.error,
              message: state.message,
            ),
        },
      ),
    );
  }
}

class _QrWait extends StatefulWidget {
  const _QrWait({
    super.key,
    required this.publicUrl,
    required this.expiresAt,
    this.error,
    this.message,
  });

  final String? publicUrl;
  final DateTime? expiresAt;
  final String? error;
  final String? message;

  @override
  State<_QrWait> createState() => _QrWaitState();
}

class _QrWaitState extends State<_QrWait> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _initSeconds() {
    if (widget.expiresAt != null) {
      final delta = widget.expiresAt!.difference(DateTime.now()).inSeconds;
      _remainingSeconds = delta > 0 ? delta : 0;
    } else {
      _remainingSeconds = 9 * 60 + 36; // 09:36 matching mockup
    }
  }

  @override
  void didUpdateWidget(covariant _QrWait oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _initSeconds();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left Column: Header, 3 Steps, Privacy Disclaimer ─────────
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Icon + Title + Underline + Subtitle
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF4DC4), Color(0xFFE6007A)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE6007A).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Scan with your ',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text: 'phone',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: colors.accentMagenta,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Accent underline pill
                          Container(
                            width: 44,
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: colors.accentMagenta,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Follow these simple steps',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 3 Steps with vertical dashed connector line
                _StepItem(
                  stepNumber: '1',
                  icon: Icons.phone_android_rounded,
                  title: 'Open your phone camera',
                  subtitle: 'and point it at this QR code',
                  isDark: isDark,
                  colors: colors,
                ),
                const SizedBox(height: 4),
                _StepConnector(isDark: isDark),
                const SizedBox(height: 4),
                _StepItem(
                  stepNumber: '2',
                  icon: Icons.link_rounded,
                  title: 'Open the link in the browser',
                  subtitle: '(no app needed)',
                  isDark: isDark,
                  colors: colors,
                ),
                const SizedBox(height: 4),
                _StepConnector(isDark: isDark),
                const SizedBox(height: 4),
                _StepItem(
                  stepNumber: '3',
                  icon: Icons.upload_file_rounded,
                  title: 'Upload a photo or a PDF',
                  subtitle: 'and complete payment if asked',
                  isDark: isDark,
                  colors: colors,
                ),

                const Spacer(),

                // Green privacy disclaimer banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.4 : 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'We do not save uploaded documents. Your phone upload is for this print session only, then deleted from the kiosk.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Middle Column: 3D Phone with QR Laser Scan Graphic ─────────
          Expanded(
            flex: 2,
            child: Center(
              child: SizedBox(
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (isDark ? const Color(0xFF7A2060) : const Color(0xFFF3E8FF))
                                .withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Image.asset(
                      'assets/new_theme_icons/how_do_you_print/qr_scan_phone.png',
                      height: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 72,
                        color: Color(0xFFE6007A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // ── Right Column: Elevated Card with Countdown, QR, Pill ───────
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF211747) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? const Color(0xFF7445BD) : const Color(0xFFE2EBF5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? const Color(0x2E8B35FF) : const Color(0x0C1B2B4F),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Top right timer capsule
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF38153A) : const Color(0xFFFCE7F3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF7A2060) : const Color(0xFFFBCFE8),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 15,
                              color: isDark ? const Color(0xFFFF6EB4) : const Color(0xFFE6007A),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Expires in $_formattedTime',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFFF6EB4) : const Color(0xFFE6007A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Large QR Code in clean container
                  Container(
                    width: 230,
                    height: 230,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE2EBF5),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: widget.publicUrl == null || widget.publicUrl!.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: Color(0xFFE6007A),
                            ),
                          )
                        : QrImageView(
                            data: widget.publicUrl!,
                            version: QrVersions.auto,
                            backgroundColor: Colors.white,
                          ),
                  ),

                  const Spacer(),

                  // Bottom helper pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E1736) : const Color(0xFFFFF0F7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF7A2060) : const Color(0xFFFBCFE8),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_android_rounded,
                          size: 16,
                          color: isDark ? const Color(0xFFFF6EB4) : const Color(0xFFE6007A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Scan the QR with your phone',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFFF6EB4) : const Color(0xFFE6007A),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (widget.error != null) ...[
                    const SizedBox(height: 8),
                    KioskStatusBanner(
                      message: widget.error!,
                      tone: KioskBannerTone.danger,
                      icon: Icons.error_outline,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single instruction step matching Image 2
class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.stepNumber,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.colors,
  });

  final String stepNumber;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Number badge
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE6007A),
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Squircle Icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF38153A) : const Color(0xFFFCE7F3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF7A2060) : const Color(0xFFFBCFE8),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: isDark ? const Color(0xFFFF6EB4) : const Color(0xFFE6007A),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Text details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dotted vertical connector line between steps
class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        children: [
          for (int i = 0; i < 4; i++) ...[
            Container(
              width: 2.2,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF7A2060) : const Color(0xFFE6007A).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Smart IT Solutions branding footer on bottom right
class _QuickPrintBrandingFooter extends StatelessWidget {
  const _QuickPrintBrandingFooter({
    required this.colors,
    required this.divider,
  });

  final AthenaColors colors;
  final Color divider;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 1, height: 26, color: divider),
        const SizedBox(width: 16),
        const Icon(
          Icons.rocket_launch_rounded,
          size: 20,
          color: Color(0xFFE6007A),
        ),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Empowering Businesses with ',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              const TextSpan(
                text: 'Smart IT Solutions',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE6007A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
