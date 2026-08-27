import 'package:flutter/foundation.dart';
import 'package:smart_auth/smart_auth.dart';

/// Android SMS User Consent helper. No-ops on non-Android platforms.
class SmsOtpListener {
  SmsOtpListener({SmartAuth? smartAuth}) : _smartAuth = smartAuth ?? SmartAuth.instance;

  final SmartAuth _smartAuth;
  bool _listening = false;

  bool get isListening => _listening;

  /// Starts User Consent listening. Resolves with extracted OTP digits, or null.
  Future<String?> listenForOtp() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    if (_listening) {
      await cancel();
    }
    _listening = true;
    try {
      final res = await _smartAuth.getSmsWithUserConsentApi(
        matcher: r'\d{4,8}',
      );
      if (!_listening) return null;
      if (res.hasData) {
        final code = res.requireData.code;
        if (code != null && code.isNotEmpty) {
          return code.replaceAll(RegExp(r'\D'), '');
        }
        final match = RegExp(r'\d{4,8}').firstMatch(res.requireData.sms);
        return match?.group(0);
      }
      return null;
    } catch (error, stack) {
      debugPrint('SmsOtpListener error: $error\n$stack');
      return null;
    } finally {
      _listening = false;
    }
  }

  Future<void> cancel() async {
    if (!_listening) return;
    _listening = false;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _smartAuth.removeUserConsentApiListener();
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
