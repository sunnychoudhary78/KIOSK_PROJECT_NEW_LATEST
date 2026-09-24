import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/network/api_client.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_mobile/features/otp_print/data/razorpay_checkout.dart';

class OtpPrintPaymentPage extends ConsumerStatefulWidget {
  const OtpPrintPaymentPage({super.key});

  @override
  ConsumerState<OtpPrintPaymentPage> createState() => _OtpPrintPaymentPageState();
}

class _OtpPrintPaymentPageState extends ConsumerState<OtpPrintPaymentPage> {
  bool _busy = false;
  String? _error;

  Future<void> _pay() async {
    final challenge = ref.read(otpPrintControllerProvider).asData?.value;
    if (challenge == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(otpPrintControllerProvider.notifier);
      final order = await notifier.createRazorpayOrder(challenge.id);
      if (order.alreadyPaid || order.otpSent) {
        if (order.otpSent || await notifier.pollUntilOtpSent()) {
          if (!mounted) return;
          await Navigator.of(context).pushReplacementNamed(AppRoutes.otpPrintSuccess);
          return;
        }
        await notifier.resendOtp();
        if (!mounted) return;
        await Navigator.of(context).pushReplacementNamed(AppRoutes.otpPrintSuccess);
        return;
      }
      if (order.orderId == null || order.orderId!.isEmpty) {
        throw Exception('Could not start payment. Try again.');
      }

      final contact = ref.read(citizenAuthProvider).phone;
      final checkout = RazorpayCheckout();
      final result = await checkout.open(
        keyId: order.keyId,
        orderId: order.orderId!,
        amountPaise: order.amountPaise,
        currency: order.currency,
        contact: contact,
      );

      final otpSent = await notifier.verifyRazorpayPayment(
        orderId: result.orderId,
        paymentId: result.paymentId,
        signature: result.signature,
      );
      if (!otpSent) {
        try {
          await notifier.resendOtp();
        } catch (_) {
          // Poll below covers webhook-first success.
        }
        final recovered = await notifier.pollUntilOtpSent();
        if (!recovered) {
          throw Exception(
            'Payment succeeded but OTP SMS is delayed. Use Resend OTP if it does not arrive.',
          );
        }
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed(AppRoutes.otpPrintSuccess);
    } on RazorpayCheckoutCancelled {
      setState(() => _error = 'Payment cancelled. You can try again.');
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final challenge = ref.watch(otpPrintControllerProvider).asData?.value;
    final quote = challenge?.quote;

    if (challenge == null || quote == null) {
      return SkpScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No payment due.',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              SkpPrimaryButton(
                label: 'Upload documents',
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed(AppRoutes.otpPrint),
              ),
            ],
          ),
        ),
      );
    }

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      safeAreaBottom: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          SkpPrimaryButton(
            label: _busy
                ? 'Processing…'
                : 'Pay ₹${quote.amountRupees.toStringAsFixed(0)}',
            loading: _busy,
            onPressed: _busy ? null : _pay,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
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
          const SizedBox(height: 12),
          Text(
            'Pay for extra pages',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'The first ${quote.freePages} page(s) are free. OTP is sent only after payment succeeds.',
            style: theme.textTheme.bodyMedium?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SkpColors.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SkpColors.line),
            ),
            child: Column(
              children: [
                Text(
                  challenge.documentLabel.isEmpty
                      ? 'Documents ready'
                      : challenge.documentLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _row(theme, 'Print color', quote.printColorLabel),
                _row(theme, 'Total pages', '${quote.pageCount}'),
                _row(theme, 'Free pages', '${quote.freePages}'),
                _row(theme, 'Extra pages', '${quote.extraPages}'),
                _row(theme, 'Charge per extra page', '₹${quote.chargePerPageRupees}'),
                const Divider(height: 28),
                _row(
                  theme,
                  'Amount due',
                  '₹${quote.amountRupees.toStringAsFixed(0)}',
                  emphasize: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: emphasize ? SkpColors.ink : SkpColors.muted,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
