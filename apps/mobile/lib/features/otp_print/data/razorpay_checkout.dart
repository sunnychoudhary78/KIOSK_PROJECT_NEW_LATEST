import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayCheckoutResult {
  const RazorpayCheckoutResult({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String paymentId;
  final String signature;
}

class RazorpayCheckoutCancelled implements Exception {
  const RazorpayCheckoutCancelled([this.message = 'Payment cancelled']);
  final String message;
  @override
  String toString() => message;
}

class RazorpayCheckout {
  RazorpayCheckout() : _razorpay = Razorpay();

  final Razorpay _razorpay;

  Future<RazorpayCheckoutResult> open({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String currency,
    String? contact,
    String name = 'Smart Kiosk Print',
  }) {
    final completer = Completer<RazorpayCheckoutResult>();

    void success(PaymentSuccessResponse response) {
      if (!completer.isCompleted) {
        completer.complete(
          RazorpayCheckoutResult(
            orderId: response.orderId ?? orderId,
            paymentId: response.paymentId ?? '',
            signature: response.signature ?? '',
          ),
        );
      }
    }

    void failure(PaymentFailureResponse response) {
      if (!completer.isCompleted) {
        final message = response.message ?? 'Payment failed';
        final cancelled = message.toLowerCase().contains('cancel');
        completer.completeError(
          cancelled ? RazorpayCheckoutCancelled(message) : Exception(message),
        );
      }
    }

    void wallet(ExternalWalletResponse response) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('External wallet ${response.walletName ?? ''} is not supported'),
        );
      }
    }

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, success);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, failure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, wallet);

    try {
      _razorpay.open({
        'key': keyId,
        'amount': amountPaise,
        'currency': currency,
        'name': name,
        'description': 'Extra print pages',
        'order_id': orderId,
        'prefill': {
          if (contact != null && contact.isNotEmpty) 'contact': contact,
        },
        'retry': {'enabled': true, 'max_count': 1},
      });
    } catch (error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }

    return completer.future.whenComplete(_razorpay.clear);
  }

  void dispose() {
    _razorpay.clear();
  }
}
