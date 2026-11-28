import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/format.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/auth/application/sms_otp_listener.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

abstract final class _LoginPalette {
  static const purpleDeep = Color(0xFF3B0A6B);
  static const purple = Color(0xFF6B2DBA);
  static const pink = Color(0xFFFF4FA3);
  static const magenta = Color(0xFFE84AB5);
  static const violet = Color(0xFF8B5CFF);
  static const blue = Color(0xFF4DA3FF);
  static const muted = Color(0xFF6B6A7A);
  static const ink = Color(0xFF1A1A1A);
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();
  final _smsListener = SmsOtpListener();
  Timer? _resendTicker;
  bool _autoVerifying = false;
  late final AnimationController _stepAnim;
  late final Animation<double> _stepFade;

  @override
  void initState() {
    super.initState();
    _stepAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1,
    );
    _stepFade = CurvedAnimation(parent: _stepAnim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _resendTicker?.cancel();
    unawaited(_smsListener.cancel());
    _phone.dispose();
    _otp.dispose();
    _otpFocus.dispose();
    _stepAnim.dispose();
    super.dispose();
  }

  void _startResendTicker() {
    _resendTicker?.cancel();
    _resendTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (ref.read(citizenAuthProvider).canResend) {
        _resendTicker?.cancel();
      }
    });
  }

  Future<void> _animateStepChange() async {
    await _stepAnim.reverse();
    if (!mounted) return;
    await _stepAnim.forward();
  }

  Future<void> _startSmsListener() async {
    final code = await _smsListener.listenForOtp();
    if (!mounted || code == null || code.isEmpty) return;
    _otp.text = code;
    _otp.selection = TextSelection.collapsed(offset: _otp.text.length);
    if (code.length >= 6) {
      await _verify(code);
    }
  }

  Future<void> _verify(String otp) async {
    if (_autoVerifying) return;
    final auth = ref.read(citizenAuthProvider);
    if (auth.loading) return;
    _autoVerifying = true;
    try {
      await ref.read(citizenAuthProvider.notifier).verifyOtp(
            phone: auth.phone ?? _phone.text.trim(),
            otp: otp.trim(),
          );
    } finally {
      _autoVerifying = false;
    }
  }

  Future<void> _requestOtp() async {
    await _smsListener.cancel();
    await ref.read(citizenAuthProvider.notifier).requestOtp(
          phone: _phone.text.trim(),
        );
  }

  Future<void> _changeNumber() async {
    await _smsListener.cancel();
    _otp.clear();
    ref.read(citizenAuthProvider.notifier).resetOtpStep();
    await _animateStepChange();
  }

  void _appendOtpDigit(String digit) {
    if (ref.read(citizenAuthProvider).loading) return;
    if (_otp.text.length >= 6) return;
    _otp.text = '${_otp.text}$digit';
    _otp.selection = TextSelection.collapsed(offset: _otp.text.length);
    if (_otp.text.length >= 6) {
      unawaited(_verify(_otp.text));
    } else {
      setState(() {});
    }
  }

  void _backspaceOtp() {
    if (ref.read(citizenAuthProvider).loading) return;
    if (_otp.text.isEmpty) return;
    _otp.text = _otp.text.substring(0, _otp.text.length - 1);
    _otp.selection = TextSelection.collapsed(offset: _otp.text.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(citizenAuthProvider);
    final l10n = AppLocalizations.of(context);

    ref.listen(citizenAuthProvider, (previous, next) {
      if (next.isAuthenticated) {
        unawaited(_smsListener.cancel());
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }

      final enteredOtpStep = next.otpSent && !(previous?.otpSent ?? false);
      final otpRequestSucceeded = previous?.loading == true &&
          next.otpSent &&
          !next.loading &&
          next.error == null;

      if (enteredOtpStep) {
        unawaited(_animateStepChange());
        unawaited(_startSmsListener());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _otpFocus.requestFocus();
          SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        });
      } else if (otpRequestSucceeded && (previous?.otpSent ?? false)) {
        unawaited(_startSmsListener());
      }

      if (next.otpSent && next.resendAvailableAt != null) {
        _startResendTicker();
      }

      if (previous?.phone != null &&
          next.phone != null &&
          next.phone != previous!.phone) {
        _phone.text = next.phone!;
      }
    });

    if (auth.restoring) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.otpSent) {
      return _buildOtpStep(auth, l10n);
    }
    return _buildPhoneStep(auth, l10n);
  }

  Widget _buildPhoneStep(CitizenAuthState auth, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -size.width * 0.12,
            top: -size.height * 0.04,
            child: IgnorePointer(
              child: SizedBox(
                width: size.width * 0.7,
                height: size.height * 0.28,
                child: const CustomPaint(painter: _TopWavePainter()),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: size.height * 0.14,
            child: IgnorePointer(
              child: SizedBox(
                width: size.width * 0.48,
                height: size.height * 0.3,
                child: const CustomPaint(painter: _PurpleKioskPainter()),
              ),
            ),
          ),
          Positioned(
            left: -6,
            top: size.height * 0.42,
            child: IgnorePointer(
              child: SizedBox(
                width: 86,
                height: 100,
                child: CustomPaint(
                  painter: _LeafClusterPainter(
                    color: _LoginPalette.violet.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.36,
            child: const IgnorePointer(
              child: CustomPaint(painter: _BottomWavePainter()),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _RoundBackButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: FadeTransition(
                      opacity: _stepFade,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StepPill(label: l10n.stepOf(1, 2)),
                            const SizedBox(height: 16),
                            Text(
                              l10n.loginWelcome,
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w700,
                                color: _LoginPalette.purpleDeep,
                                fontSize: 34,
                                height: 1.05,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const SizedBox(
                              width: 96,
                              height: 16,
                              child: CustomPaint(painter: _PinkSwooshPainter()),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: size.width * 0.58,
                              ),
                              child: Text(
                                l10n.loginHelper,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _LoginPalette.muted,
                                  fontSize: 14,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(height: size.height * 0.08),
                            _PhoneField(
                              controller: _phone,
                              enabled: !auth.loading,
                              hint: l10n.mobileNumber,
                            ),
                            if (auth.error != null) ...[
                              const SizedBox(height: 16),
                              SkpStatusBanner(
                                message: auth.error!,
                                tone: SkpBannerTone.danger,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  _GradientCtaButton(
                    label: l10n.sendOtp,
                    loading: auth.loading,
                    onPressed: _requestOtp,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(CitizenAuthState auth, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final phoneLabel = maskPhone(auth.phone ?? _phone.text);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  right: -size.width * 0.12,
                  top: -size.height * 0.04,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: size.width * 0.7,
                      height: size.height * 0.28,
                      child: const CustomPaint(painter: _TopWavePainter()),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: size.height * 0.1,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: const CustomPaint(painter: _ShieldLockPainter()),
                    ),
                  ),
                ),
                Positioned(
                  left: -6,
                  top: size.height * 0.36,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 86,
                      height: 100,
                      child: CustomPaint(
                        painter: _LeafClusterPainter(
                          color: _LoginPalette.violet.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: size.height * 0.28,
                  child: const IgnorePointer(
                    child: CustomPaint(painter: _BottomWavePainter()),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
                    child: FadeTransition(
                      opacity: _stepFade,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _RoundBackButton(onPressed: _changeNumber),
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _StepPill(label: l10n.stepOf(2, 2)),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.enterOtp,
                                    style: theme.textTheme.displaySmall
                                        ?.copyWith(
                                      fontFamily: 'serif',
                                      fontWeight: FontWeight.w700,
                                      color: _LoginPalette.purpleDeep,
                                      fontSize: 34,
                                      height: 1.05,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const SizedBox(
                                    width: 96,
                                    height: 16,
                                    child: CustomPaint(
                                      painter: _PinkSwooshPainter(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: size.width * 0.58,
                                    ),
                                    child: Text(
                                      l10n.otpSentTo(phoneLabel),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: _LoginPalette.muted,
                                        fontSize: 14,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: size.height * 0.05),
                                  SkpOtpPinField(
                                    controller: _otp,
                                    focusNode: _otpFocus,
                                    enabled: !auth.loading,
                                    useNativeKeyboard: false,
                                    accentColor: _LoginPalette.pink,
                                    onCompleted: _verify,
                                  ),
                                  if (auth.error != null) ...[
                                    const SizedBox(height: 16),
                                    SkpStatusBanner(
                                      message: auth.error!,
                                      tone: SkpBannerTone.danger,
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      _OtpTextAction(
                                        icon: Icons.refresh_rounded,
                                        label: l10n.changeNumber,
                                        onPressed: auth.loading
                                            ? null
                                            : _changeNumber,
                                      ),
                                      const Spacer(),
                                      _OtpTextAction(
                                        icon: Icons.schedule_rounded,
                                        label: auth.canResend
                                            ? l10n.resendOtp
                                            : l10n.resendIn(
                                                auth.resendSecondsLeft,
                                              ),
                                        onPressed: auth.loading ||
                                                !auth.canResend
                                            ? null
                                            : () async {
                                                _otp.clear();
                                                await _requestOtp();
                                              },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _GradientCtaButton(
                            label: l10n.verifyContinue,
                            loading: auth.loading,
                            onPressed: () => _verify(_otp.text),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _OtpKeypad(
            enabled: !auth.loading,
            onDigit: _appendOtpDigit,
            onBackspace: _backspaceOtp,
            onSubmit: () => _verify(_otp.text),
          ),
        ],
      ),
    );
  }
}

class _OtpTextAction extends StatelessWidget {
  const _OtpTextAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled
        ? _LoginPalette.purpleDeep
        : _LoginPalette.muted.withValues(alpha: 0.55);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpKeypad extends StatelessWidget {
  const _OtpKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(28, 18, 28, 14 + bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _LoginPalette.purpleDeep,
            Color(0xFF5A1A9A),
            _LoginPalette.magenta,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final d in row)
                    _KeypadKey(
                      label: d,
                      onTap: enabled ? () => onDigit(d) : null,
                    ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _KeypadKey(
                icon: Icons.backspace_outlined,
                onTap: enabled ? onBackspace : null,
              ),
              _KeypadKey(
                label: '0',
                onTap: enabled ? () => onDigit('0') : null,
              ),
              _KeypadKey(
                icon: Icons.check_rounded,
                accent: true,
                onTap: enabled ? onSubmit : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    this.label,
    this.icon,
    this.onTap,
    this.accent = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final bg = accent
        ? _LoginPalette.pink
        : Colors.white.withValues(alpha: 0.12);
    final fg = Colors.white;

    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Center(
            child: icon != null
                ? Icon(icon, color: fg, size: 26)
                : Text(
                    label ?? '',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.arrow_back_rounded,
            color: _LoginPalette.purpleDeep,
          ),
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD6EC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _LoginPalette.pink,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.enabled,
    required this.hint,
  });

  final TextEditingController controller;
  final bool enabled;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fieldStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: _LoginPalette.ink,
    );
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _LoginPalette.purple.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.phone_rounded,
            color: _LoginPalette.purpleDeep,
            size: 20,
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 20, color: const Color(0xFFE5E5EA)),
          const SizedBox(width: 10),
          Text(
            '+91',
            style: fieldStyle?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: fieldStyle?.copyWith(letterSpacing: 0.4),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: fieldStyle?.copyWith(
                  color: _LoginPalette.muted.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                counterText: '',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientCtaButton extends StatelessWidget {
  const _GradientCtaButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _LoginPalette.purpleDeep,
            _LoginPalette.violet,
            _LoginPalette.pink,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _LoginPalette.pink.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: loading ? null : onPressed,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PinkSwooshPainter extends CustomPainter {
  const _PinkSwooshPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [
          _LoginPalette.pink,
          _LoginPalette.magenta,
          _LoginPalette.violet,
        ],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.05,
        size.width * 0.7,
        size.height * 0.45,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.7,
        size.width,
        size.height * 0.35,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopWavePainter extends CustomPainter {
  const _TopWavePainter({this.flip = false});

  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    if (flip) {
      canvas.translate(size.width, size.height);
      canvas.scale(-1, -1);
    }

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          _LoginPalette.pink,
          _LoginPalette.magenta,
          _LoginPalette.violet,
          _LoginPalette.blue,
        ],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(size.width * 0.2, 0)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.2,
        size.width * 0.62,
        size.height * 0.16,
      )
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.1,
        size.width,
        size.height * 0.4,
      )
      ..quadraticBezierTo(
        size.width * 1.02,
        size.height * 0.72,
        size.width * 0.7,
        size.height * 0.9,
      )
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height * 1.02,
        size.width * 0.24,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.12,
        size.height * 0.24,
        size.width * 0.2,
        0,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TopWavePainter oldDelegate) =>
      oldDelegate.flip != flip;
}

class _BottomWavePainter extends CustomPainter {
  const _BottomWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          _LoginPalette.blue,
          _LoginPalette.violet,
          _LoginPalette.magenta,
          _LoginPalette.pink,
        ],
      ).createShader(Offset.zero & size);

    final wave = Path()
      ..moveTo(0, size.height * 0.3)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.08,
        size.width * 0.38,
        size.height * 0.42,
        size.width * 0.55,
        size.height * 0.28,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.14,
        size.width * 0.88,
        size.height * 0.06,
        size.width,
        size.height * 0.2,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(wave, paint);

    final crest = Path()
      ..moveTo(0, size.height * 0.3)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.08,
        size.width * 0.38,
        size.height * 0.42,
        size.width * 0.55,
        size.height * 0.28,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.14,
        size.width * 0.88,
        size.height * 0.06,
        size.width,
        size.height * 0.2,
      );

    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = Colors.white.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LeafClusterPainter extends CustomPainter {
  const _LeafClusterPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    void leaf(Offset tip, double angle, double len, double width) {
      canvas.save();
      canvas.translate(tip.dx, tip.dy);
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(width, -len * 0.45, 0, -len)
        ..quadraticBezierTo(-width, -len * 0.45, 0, 0)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    leaf(Offset(size.width * 0.45, size.height * 0.75), -0.5, 58, 18);
    leaf(Offset(size.width * 0.55, size.height * 0.7), 0.15, 48, 15);
    leaf(Offset(size.width * 0.35, size.height * 0.62), -1.1, 40, 13);
  }

  @override
  bool shouldRepaint(covariant _LeafClusterPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PurpleKioskPainter extends CustomPainter {
  const _PurpleKioskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sparkle = Paint()..color = _LoginPalette.pink.withValues(alpha: 0.85);
    void star(Offset o, double r) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = (i / 4) * math.pi * 2 - math.pi / 2;
        final p = o + Offset(math.cos(a), math.sin(a)) * r;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
        final b = a + math.pi / 4;
        final q = o + Offset(math.cos(b), math.sin(b)) * (r * 0.35);
        path.lineTo(q.dx, q.dy);
      }
      path.close();
      canvas.drawPath(path, sparkle);
    }

    star(Offset(size.width * 0.72, size.height * 0.18), 8);
    star(Offset(size.width * 0.84, size.height * 0.28), 5);
    star(Offset(size.width * 0.62, size.height * 0.12), 4);

    final kiosk = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.28,
        size.height * 0.32,
        size.width * 0.42,
        size.height * 0.48,
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      kiosk,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _LoginPalette.violet,
            _LoginPalette.purple,
            _LoginPalette.purpleDeep,
          ],
        ).createShader(kiosk.outerRect),
    );

    final screen = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.34,
        size.height * 0.38,
        size.width * 0.3,
        size.height * 0.16,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(screen, Paint()..color = const Color(0xFFF3E9FF));

    final paper = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.38,
        size.height * 0.52,
        size.width * 0.22,
        size.height * 0.2,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(paper, Paint()..color = Colors.white);
    final linePaint = Paint()
      ..color = const Color(0xFFE0D4F5)
      ..strokeWidth = 2;
    for (var i = 0; i < 4; i++) {
      final y = size.height * 0.56 + i * 8;
      canvas.drawLine(
        Offset(size.width * 0.42, y),
        Offset(size.width * 0.56, y),
        linePaint,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.49, size.height * 0.86),
        width: size.width * 0.38,
        height: 14,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShieldLockPainter extends CustomPainter {
  const _ShieldLockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.48, size.height * 0.5);

    canvas.drawCircle(
      c,
      size.width * 0.38,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..shader = const LinearGradient(
          colors: [
            _LoginPalette.pink,
            _LoginPalette.violet,
            _LoginPalette.blue,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.4)),
    );

    final leafPaint = Paint()..color = _LoginPalette.magenta.withValues(alpha: 0.75);
    void leaf(Offset o, double a, double l) {
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(a);
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(10, -l * 0.4, 0, -l)
        ..quadraticBezierTo(-10, -l * 0.4, 0, 0);
      canvas.drawPath(p, leafPaint);
      canvas.restore();
    }

    leaf(c + const Offset(48, -18), 0.6, 28);
    leaf(c + const Offset(42, 8), 1.2, 24);
    leaf(c + const Offset(-46, -10), -0.7, 26);

    final shield = Path()
      ..moveTo(c.dx, c.dy - 42)
      ..cubicTo(c.dx + 34, c.dy - 38, c.dx + 38, c.dy - 10, c.dx + 34, c.dy + 8)
      ..cubicTo(c.dx + 28, c.dy + 34, c.dx + 10, c.dy + 46, c.dx, c.dy + 52)
      ..cubicTo(c.dx - 10, c.dy + 46, c.dx - 28, c.dy + 34, c.dx - 34, c.dy + 8)
      ..cubicTo(c.dx - 38, c.dy - 10, c.dx - 34, c.dy - 38, c.dx, c.dy - 42)
      ..close();

    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _LoginPalette.violet,
            _LoginPalette.purple,
            _LoginPalette.purpleDeep,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: 55)),
    );

    final lockRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c + const Offset(0, 6), width: 28, height: 22),
      const Radius.circular(5),
    );
    canvas.drawRRect(lockRect, Paint()..color = Colors.white);

    canvas.drawArc(
      Rect.fromCenter(center: c + const Offset(0, -6), width: 18, height: 18),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
