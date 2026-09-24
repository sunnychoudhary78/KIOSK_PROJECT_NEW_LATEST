import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/core/network/api_client.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_models.dart';
import 'package:skp_mobile/features/otp_print/application/print_history_controller.dart';

export 'package:skp_mobile/features/otp_print/application/otp_print_models.dart';

class OtpPrintController extends AsyncNotifier<OtpChallenge?> {
  @override
  Future<OtpChallenge?> build() async => null;

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> createChallenge({
    required List<File> files,
    String? documentLabel,
    String printColorMode = 'bw',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _api.postMultipart(
        '/otp-challenges',
        fields: {
          if (documentLabel != null && documentLabel.isNotEmpty)
            'documentLabel': documentLabel,
          'printColorMode': printColorMode == 'color' ? 'color' : 'bw',
        },
        files: files,
        fileField: 'files',
      );
      return OtpChallenge.fromJson(result);
    });
    if (state.hasValue && state.value != null) {
      ref.invalidate(printHistoryProvider);
    }
  }

  Future<void> loadChallenge(String challengeId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await _api.get('/otp-challenges/$challengeId');
      return OtpChallenge.fromJson(result);
    });
  }

  Future<RazorpayOrder> createRazorpayOrder(String challengeId) async {
    final result = await _retry(
      () => _api.post(
        '/payments/razorpay/order',
        body: {'challengeId': challengeId},
      ),
    );
    return RazorpayOrder.fromJson(result);
  }

  Future<bool> verifyRazorpayPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final result = await _retry(
        () => _api.post(
          '/payments/razorpay/verify',
          body: {
            'razorpay_order_id': orderId,
            'razorpay_payment_id': paymentId,
            'razorpay_signature': signature,
          },
        ),
      );
      if (result['otpSent'] == true) {
        await refreshChallenge();
        return true;
      }
    } on ApiException catch (error) {
      if (!error.isRetryable && error.code != 'sms_failed') {
        rethrow;
      }
    }
    return pollUntilOtpSent();
  }

  Future<void> refreshChallenge() async {
    final current = state.asData?.value;
    if (current == null) return;
    final result = await _api.get('/otp-challenges/${current.id}');
    state = AsyncData(OtpChallenge.fromJson(result));
  }

  Future<bool> pollUntilOtpSent({int attempts = 8}) async {
    final current = state.asData?.value;
    if (current == null) return false;
    for (var i = 0; i < attempts; i++) {
      final result = await _api.get('/otp-challenges/${current.id}');
      final challenge = OtpChallenge.fromJson(result);
      state = AsyncData(challenge);
      if (challenge.otpSent) return true;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return state.asData?.value?.otpSent ?? false;
  }

  Future<void> resendOtp() async {
    final current = state.asData?.value;
    if (current == null) return;
    await _api.post('/otp-challenges/${current.id}/resend-otp');
    await refreshChallenge();
    ref.invalidate(printHistoryProvider);
  }

  void clear() {
    state = const AsyncData(null);
  }

  Future<Map<String, dynamic>> _retry(
    Future<Map<String, dynamic>> Function() request, {
    int times = 3,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < times; attempt++) {
      try {
        return await request();
      } on ApiException catch (error) {
        lastError = error;
        if (!error.isRetryable || attempt == times - 1) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw lastError ?? const ApiException('Request failed');
  }
}

final otpPrintControllerProvider =
    AsyncNotifierProvider<OtpPrintController, OtpChallenge?>(OtpPrintController.new);
