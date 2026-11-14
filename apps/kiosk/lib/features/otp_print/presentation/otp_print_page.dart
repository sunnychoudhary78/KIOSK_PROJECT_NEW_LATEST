import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/input/kiosk_hardware_key_map.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/ads/presentation/kiosk_wait_ads.dart';
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

  Future<void> _endSession() async {
    await ref.read(otpPrintControllerProvider.notifier).abandonRetry();
    await ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  Future<void> _goBack() async {
    ref.read(otpPrintControllerProvider.notifier).reset();
    if (!mounted) return;
    Navigator.of(context).pop();
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
    if ((kioskPrintingPaused(ref) || state.paperOut) &&
        state.phase != OtpPrintPhase.printing) {
      return VisitorSessionPopScope(
        endSessionOnPop: false,
        child: KioskShell(
          title: 'OTP Print',
          onHome: _endSession,
          body: const KioskPrintingPaused(),
        ),
      );
    }

    Widget? leading;
    Widget? trailing;
    String? step;
    if (entering) {
      leading = KioskGhostButton(
        label: 'Back',
        icon: Icons.arrow_back,
        onPressed: _goBack,
      );
      trailing = _ContinueButton(
        enabled: !state.loading && _otp.length >= 4,
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
      trailing = state.printFailures >= 2
          ? KioskPrimaryButton(
              label: 'Tell staff',
              onPressed: controller.tellStaff,
            )
          : KioskPrimaryButton(
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
      trailing = KioskGhostButton(
        label: 'Cancel',
        onPressed: _endSession,
      );
      step = 'Documents';
    }

    Widget page = VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: 'Print Documents',
        titleIcon: Icons.print_rounded,
        onHome: _endSession,
        stepLabel: step,
        footerLeading: leading,
        footerTrailing: trailing,
        body: switch (state.phase) {
          OtpPrintPhase.redeeming || OtpPrintPhase.preparingPreview => KioskWaitAds(
              message: state.phase == OtpPrintPhase.preparingPreview
                  ? 'Preparing document preview…'
                  : 'Fetching documents…',
            ),
          OtpPrintPhase.printing => KioskPrintingProgress(detail: state.message),
          OtpPrintPhase.previewing when state.previewBytes != null =>
            KioskPdfPreview(
              title: state.previewDoc?.fileName ?? 'Document',
              pdfBytes: state.previewBytes!,
              error: state.error,
              message: state.message,
            ),
          OtpPrintPhase.printResult => KioskPrintResult(
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
                          '${doc.pageCount} page(s) · ${state.redeemResult?.printColorLabel ?? 'B/W'}'
                          '${doc.printed ? ' · Printed' : ''}',
                      actionLabel: doc.printed ? 'Printed' : 'Preview',
                      onAction: state.loading || doc.printed
                          ? null
                          : () => controller.preparePreview(doc),
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

    if (!entering) {
      return page;
    }
    return KioskHardwareKeys(
      onKeyEvent: (event) {
        final command = mapOtpHardwareKey(event);
        if (command == null) {
          return KeyEventResult.ignored;
        }
        switch (command.action) {
          case OtpHardwareAction.digit:
            _appendDigit(command.digit ?? '');
          case OtpHardwareAction.backspace:
            _backspace();
          case OtpHardwareAction.clear:
            _clear();
          case OtpHardwareAction.submit:
            if (!state.loading && _otp.length >= 4) {
              controller.redeem(_otp);
            }
        }
        return KeyEventResult.handled;
      },
      child: page,
    );
  }
}

class _OtpEntry extends StatefulWidget {
  const _OtpEntry({
    super.key,
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
  State<_OtpEntry> createState() => _OtpEntryState();
}

class _OtpEntryState extends State<_OtpEntry> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 9 * 60 + 36; // 09:36 matching mockup
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });
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
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left Column: Header, Privacy, 3D Phone, PIN slots, Timer ───
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
                        child: Icon(Icons.chat_bubble_rounded, size: 26, color: Colors.white),
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
                                  text: 'Enter the OTP sent by ',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text: 'SMS',
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
                            'Use the keypad to enter the 6-digit code. No phone keyboard is needed.',
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

                const SizedBox(height: 12),

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
                          'We do not save your documents or OTP. Content is fetched only to print now, then cleared.',
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

                const Spacer(),

                // 3D Phone with OTP password speech bubble
                Center(
                  child: SizedBox(
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft ambient halo
                        Container(
                          width: 150,
                          height: 150,
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
                          'assets/new_theme_icons/how_do_you_print/otp_password_phone.png',
                          height: 120,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.sms_rounded,
                            size: 64,
                            color: Color(0xFFE6007A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 6 PIN Slots matching Image 1
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < 6; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        _PinSlotItem(
                          index: i,
                          value: widget.otp,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Timer countdown pill
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
                          size: 16,
                          color: isDark ? const Color(0xFFFF6EB4) : const Color(0xFFE6007A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Expires in $_formattedTime',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFFF6EB4) : const Color(0xFFE6007A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                if (widget.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: KioskStatusBanner(
                      message: widget.error!,
                      tone: KioskBannerTone.danger,
                      icon: Icons.error_outline,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 32),

          // ── Right Column: Large Elevated Keypad Card ──────────────────
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
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['C', '0', '⌫'],
                  ])
                    Expanded(
                      child: Row(
                        children: [
                          for (final key in row)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: _OtpKeypadButton(
                                  label: key,
                                  onTap: () {
                                    if (key == 'C') {
                                      widget.onClear();
                                    } else if (key == '⌫') {
                                      widget.onBackspace();
                                    } else {
                                      widget.onDigit(key);
                                    }
                                  },
                                  isDark: isDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single PIN slot matching Image 1
class _PinSlotItem extends StatelessWidget {
  const _PinSlotItem({
    required this.index,
    required this.value,
    required this.isDark,
  });

  final int index;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hasChar = index < value.length;
    final isActive = index == value.length;

    final Color bgColor = isDark
        ? const Color(0xFF281C54)
        : Colors.white;

    final Color borderColor = isActive
        ? const Color(0xFFE6007A)
        : (hasChar
            ? const Color(0xFF0084FF)
            : (isDark ? const Color(0xFF4A347D) : const Color(0xFFDCE4EE)));

    return Container(
      width: 54,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: isActive ? 2.0 : 1.2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFE6007A).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: isDark ? Colors.transparent : const Color(0x061B2B4F),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: isActive
          ? Container(
              width: 2.2,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFE6007A),
                borderRadius: BorderRadius.circular(1),
              ),
            )
          : Text(
              hasChar ? value[index] : '',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1B2234),
              ),
            ),
    );
  }
}

/// Modern squircle keypad button matching Image 1
class _OtpKeypadButton extends StatelessWidget {
  const _OtpKeypadButton({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isClear = label == 'C';
    final isBackspace = label == '⌫';

    Color bgColor;
    Color borderColor;

    if (isClear) {
      bgColor = isDark ? const Color(0xFF3A2D12) : const Color(0xFFFFFBEB);
      borderColor = isDark ? const Color(0xFF855D15) : const Color(0xFFFDE68A);
    } else if (isBackspace) {
      bgColor = isDark ? const Color(0xFF38153A) : const Color(0xFFFCE7F3);
      borderColor = isDark ? const Color(0xFF7A2060) : const Color(0xFFFBCFE8);
    } else {
      bgColor = isDark ? const Color(0xFF281C54) : const Color(0xFFF8FAFC);
      borderColor = isDark ? const Color(0xFF4A347D) : const Color(0xFFE2EBF5);
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.transparent : const Color(0x061B2B4F),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: isBackspace
                ? Icon(
                    Icons.backspace_outlined,
                    size: 24,
                    color: isDark ? const Color(0xFFFF6EB4) : const Color(0xFFE6007A),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isClear
                          ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                          : (isDark ? Colors.white : const Color(0xFF1B2234)),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Solid pink gradient Continue button matching Image 1
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFFFF4DC4), Color(0xFFE6007A)],
                  )
                : null,
            color: enabled ? null : (isDark ? const Color(0xFF261D49) : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(26),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFFE6007A).withValues(alpha: 0.38),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              else ...[
                Text(
                  'Continue',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: enabled ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: enabled ? Colors.white : const Color(0xFF94A3B8),
                ),
              ],
            ],
          ),
        ),
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
