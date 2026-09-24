import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/format.dart';
import 'package:skp_mobile/core/network/api_client.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_mobile/features/otp_print/data/razorpay_checkout.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final challenge = ref.watch(otpPrintControllerProvider).asData?.value;
    final quote = challenge?.quote;

    if (challenge == null || quote == null) {
      return SkpScaffold(
        body: SkpEmptyState(
          icon: Icons.payments_outlined,
          title: l10n.noPaymentDue,
          message: l10n.noActiveSessionHelper,
          actionLabel: l10n.uploadDocuments,
          onAction: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.otpPrint),
        ),
      );
    }

    final amount = formatRupees(quote.amountRupees);

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      safeAreaBottom: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            SkpStatusBanner(message: _error!, tone: SkpBannerTone.danger),
            const SizedBox(height: 8),
          ],
          SkpPrimaryButton(
            label: _busy ? l10n.processing : l10n.payAmount(amount),
            loading: _busy,
            onPressed: _busy ? null : _pay,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkpPageHeader(
            title: l10n.payExtraPages,
            subtitle: l10n.payHelper(quote.freePages),
            showBack: true,
            backEnabled: !_busy,
          ),
          const SizedBox(height: 24),
          SkpPanelCard(
            child: Column(
              children: [
                Text(
                  amount,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: SkpColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.amountDue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: SkpColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  challenge.documentLabel.isEmpty
                      ? l10n.documentsReady
                      : challenge.documentLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _row(theme, l10n.printColorLabel, quote.printColorLabel),
                _row(theme, l10n.totalPages, '${quote.pageCount}'),
                _row(theme, l10n.freePages, '${quote.freePages}'),
                _row(theme, l10n.extraPages, '${quote.extraPages}'),
                _row(theme, l10n.chargePerPage, '₹${quote.chargePerPageRupees}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: SkpColors.muted,
                fontWeight: FontWeight.w500,
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
