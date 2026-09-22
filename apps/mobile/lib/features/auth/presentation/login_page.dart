import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/auth/application/sms_otp_listener.dart';

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

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return phone;
    return '+91 ${digits.substring(0, 2)}••••${digits.substring(digits.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(citizenAuthProvider);
    final theme = Theme.of(context);

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
          if (mounted) _otpFocus.requestFocus();
        });
      } else if (otpRequestSucceeded && (previous?.otpSent ?? false)) {
        // Resend — restart User Consent listener for the new SMS.
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
      return const SkpScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(
                backgroundColor: SkpColors.panel,
                side: const BorderSide(color: SkpColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 20),
          FadeTransition(
            opacity: _stepFade,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  auth.otpSent ? 'Enter OTP' : 'Welcome',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  auth.otpSent
                      ? 'We sent a one-time code to ${_maskPhone(auth.phone ?? _phone.text)}'
                      : 'Sign in with your mobile number to upload documents and print at a kiosk.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: SkpColors.muted,
                  ),
                ),
                const SizedBox(height: 32),
                if (!auth.otpSent)
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    enabled: !auth.loading,
                    maxLength: 10,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      hintText: '10-digit mobile',
                      prefixText: '+91  ',
                      counterText: '',
                    ),
                  )
                else
                  SkpOtpPinField(
                    controller: _otp,
                    focusNode: _otpFocus,
                    enabled: !auth.loading,
                    onCompleted: _verify,
                  ),
              ],
            ),
          ),
          const Spacer(),
          if (auth.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                auth.error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (!auth.otpSent)
            SkpPrimaryButton(
              label: 'Send OTP',
              loading: auth.loading,
              onPressed: _requestOtp,
            )
          else ...[
            SkpPrimaryButton(
              label: 'Verify & continue',
              loading: auth.loading,
              onPressed: () => _verify(_otp.text),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SkpTextLink(
                  label: 'Change number',
                  onPressed: auth.loading ? null : _changeNumber,
                ),
                const Spacer(),
                SkpTextLink(
                  label: auth.canResend
                      ? 'Resend OTP'
                      : 'Resend in ${auth.resendSecondsLeft}s',
                  onPressed: auth.loading || !auth.canResend
                      ? null
                      : () async {
                          _otp.clear();
                          await _requestOtp();
                        },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
