import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skp_mobile/core/auth/jwt_utils.dart';
import 'package:skp_mobile/core/network/api_client.dart';

const _tokenPrefsKey = 'skp_citizen_access_token';
const _phonePrefsKey = 'skp_citizen_phone';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class CitizenAuthState {
  const CitizenAuthState({
    this.token,
    this.error,
    this.loading = false,
    this.otpSent = false,
    this.phone,
    this.restoring = false,
    this.resendAvailableAt,
  });

  final String? token;
  final String? error;
  final bool loading;
  final bool otpSent;
  final String? phone;
  final bool restoring;
  final DateTime? resendAvailableAt;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  bool get canResend {
    final until = resendAvailableAt;
    if (until == null) return true;
    return DateTime.now().isAfter(until);
  }

  int get resendSecondsLeft {
    final until = resendAvailableAt;
    if (until == null) return 0;
    final left = until.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }
}

class CitizenAuthNotifier extends Notifier<CitizenAuthState> {
  bool _loggingOut = false;

  @override
  CitizenAuthState build() {
    _api.onUnauthorized = _handleUnauthorized;
    Future.microtask(restoreSession);
    return const CitizenAuthState(restoring: true);
  }

  ApiClient get _api => ref.read(apiClientProvider);

  void _handleUnauthorized() {
    unawaited(logout());
  }

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenPrefsKey);
      final phone = prefs.getString(_phonePrefsKey);
      if (token != null && token.isNotEmpty && !isJwtExpired(token)) {
        _api.setAccessToken(token);
        state = CitizenAuthState(token: token, phone: phone);
      } else {
        if (token != null && token.isNotEmpty) {
          await _persistSession();
        }
        _api.setAccessToken(null);
        state = const CitizenAuthState();
      }
    } catch (_) {
      _api.setAccessToken(null);
      state = const CitizenAuthState();
    }
  }

  Future<void> _persistSession({String? token, String? phone}) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_tokenPrefsKey);
      await prefs.remove(_phonePrefsKey);
    } else {
      await prefs.setString(_tokenPrefsKey, token);
      if (phone != null && phone.isNotEmpty) {
        await prefs.setString(_phonePrefsKey, phone);
      }
    }
  }

  static String? validatePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  Future<void> requestOtp({required String phone}) async {
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    final validationError = validatePhone(normalized);
    if (validationError != null) {
      state = CitizenAuthState(error: validationError, phone: phone);
      return;
    }

    final wasOtpSent = state.otpSent;
    state = CitizenAuthState(loading: true, phone: normalized, otpSent: wasOtpSent);
    try {
      await _api.post(
        '/auth/citizen/otp-request',
        body: {'phone': normalized},
      );
      state = CitizenAuthState(
        otpSent: true,
        phone: normalized,
        resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
      );
    } catch (error) {
      state = CitizenAuthState(
        error: error.toString(),
        phone: normalized,
        otpSent: wasOtpSent,
      );
    }
  }

  Future<void> verifyOtp({required String phone, required String otp}) async {
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    if (otp.trim().isEmpty) {
      state = CitizenAuthState(
        error: 'Enter the OTP sent to your phone',
        otpSent: true,
        phone: normalized,
      );
      return;
    }

    state = CitizenAuthState(loading: true, otpSent: true, phone: normalized);
    try {
      final result = await _api.post(
        '/auth/citizen/otp-verify',
        body: {'phone': normalized, 'otp': otp.trim()},
      );
      final token = result['accessToken'] as String;
      _api.setAccessToken(token);
      await _persistSession(token: token, phone: normalized);
      state = CitizenAuthState(token: token, phone: normalized);
    } catch (error) {
      state = CitizenAuthState(
        error: error.toString(),
        otpSent: true,
        phone: normalized,
      );
    }
  }

  void resetOtpStep() {
    state = CitizenAuthState(phone: state.phone);
  }

  Future<void> logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      _api.setAccessToken(null);
      await _persistSession();
      state = const CitizenAuthState();
    } finally {
      _loggingOut = false;
    }
  }
}

final citizenAuthProvider =
    NotifierProvider<CitizenAuthNotifier, CitizenAuthState>(CitizenAuthNotifier.new);
