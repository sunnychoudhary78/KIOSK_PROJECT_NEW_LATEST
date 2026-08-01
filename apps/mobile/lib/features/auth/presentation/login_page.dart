import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phone = TextEditingController(text: '9999999999');
  final _otp = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(citizenAuthProvider);
    ref.listen(citizenAuthProvider, (previous, next) {
      if (next.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
      if (next.devOtp != null && next.devOtp != previous?.devOtp && next.otpSent) {
        _otp.text = next.devOtp!;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Citizen login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              enabled: !auth.otpSent,
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                hintText: '10-digit mobile',
              ),
            ),
            if (auth.otpSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'OTP'),
              ),
            ],
            const SizedBox(height: 16),
            if (!auth.otpSent)
              FilledButton(
                onPressed: auth.loading
                    ? null
                    : () => ref.read(citizenAuthProvider.notifier).requestOtp(
                          phone: _phone.text.trim(),
                        ),
                child: Text(auth.loading ? 'Sending…' : 'Send OTP'),
              )
            else ...[
              FilledButton(
                onPressed: auth.loading
                    ? null
                    : () => ref.read(citizenAuthProvider.notifier).verifyOtp(
                          phone: _phone.text.trim(),
                          otp: _otp.text.trim(),
                        ),
                child: Text(auth.loading ? 'Verifying…' : 'Verify & sign in'),
              ),
              TextButton(
                onPressed: auth.loading
                    ? null
                    : () => ref.read(citizenAuthProvider.notifier).resetOtpStep(),
                child: const Text('Change number'),
              ),
            ],
            if (auth.devOtp != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Dev OTP: ${auth.devOtp}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  auth.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
