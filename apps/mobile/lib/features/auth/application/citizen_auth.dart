import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/core/network/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class CitizenAuthState {
  const CitizenAuthState({
    this.token,
    this.error,
    this.loading = false,
    this.otpSent = false,
    this.devOtp,
    this.phone,
  });

  final String? token;
  final String? error;
  final bool loading;
  final bool otpSent;
  final String? devOtp;
  final String? phone;

  bool get isAuthenticated => token != null;
}

class CitizenAuthNotifier extends Notifier<CitizenAuthState> {
  @override
  CitizenAuthState build() => const CitizenAuthState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> requestOtp({required String phone}) async {
    state = CitizenAuthState(loading: true, phone: phone);
    try {
      final result = await _api.post(
        '/auth/citizen/otp-request',
        body: {'phone': phone},
      );
      state = CitizenAuthState(
        otpSent: true,
        phone: phone,
        devOtp: result['devOtp'] as String?,
      );
    } catch (error) {
      state = CitizenAuthState(error: error.toString(), phone: phone);
    }
  }

  Future<void> verifyOtp({required String phone, required String otp}) async {
    state = CitizenAuthState(loading: true, otpSent: true, phone: phone);
    try {
      final result = await _api.post(
        '/auth/citizen/otp-verify',
        body: {'phone': phone, 'otp': otp},
      );
      final token = result['accessToken'] as String;
      _api.setAccessToken(token);
      state = CitizenAuthState(token: token);
    } catch (error) {
      state = CitizenAuthState(
        error: error.toString(),
        otpSent: true,
        phone: phone,
      );
    }
  }

  void resetOtpStep() {
    state = CitizenAuthState(phone: state.phone);
  }

  void logout() {
    _api.setAccessToken(null);
    state = const CitizenAuthState();
  }
}

final citizenAuthProvider =
    NotifierProvider<CitizenAuthNotifier, CitizenAuthState>(CitizenAuthNotifier.new);
