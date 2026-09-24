import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/format.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/auth/application/sms_otp_listener.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(citizenAuthProvider);
    final theme = Theme.of(context);
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
          if (mounted) _otpFocus.requestFocus();
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
      return const SkpScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: SkpBackButton(),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.stepOf(auth.otpSent ? 2 : 1, 2),
            style: theme.textTheme.bodySmall?.copyWith(
              color: SkpColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: FadeTransition(
                opacity: _stepFade,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      auth.otpSent ? l10n.enterOtp : l10n.loginWelcome,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      auth.otpSent
                          ? l10n.otpSentTo(maskPhone(auth.phone ?? _phone.text))
                          : l10n.loginHelper,
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
                        decoration: InputDecoration(
                          labelText: l10n.mobileNumber,
                          hintText: l10n.mobileHint,
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
            ),
          ),
          if (auth.error != null) ...[
            SkpStatusBanner(
              message: auth.error!,
              tone: SkpBannerTone.danger,
            ),
            const SizedBox(height: 12),
          ],
          if (!auth.otpSent)
            SkpPrimaryButton(
              label: l10n.sendOtp,
              loading: auth.loading,
              onPressed: _requestOtp,
            )
          else ...[
            SkpPrimaryButton(
              label: l10n.verifyContinue,
              loading: auth.loading,
              onPressed: () => _verify(_otp.text),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SkpTextLink(
                  label: l10n.changeNumber,
                  onPressed: auth.loading ? null : _changeNumber,
                ),
                const Spacer(),
                SkpTextLink(
                  label: auth.canResend
                      ? l10n.resendOtp
                      : l10n.resendIn(auth.resendSecondsLeft),
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
