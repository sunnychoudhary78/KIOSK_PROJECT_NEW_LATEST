import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/network/api_client.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_controller.dart';

class PaymentSupportArgs {
  const PaymentSupportArgs({
    required this.challengeId,
    required this.amountLabel,
    required this.kioskName,
    this.orderId,
  });

  final String challengeId;
  final String amountLabel;
  final String kioskName;
  final String? orderId;
}

class PaymentSupportPage extends ConsumerStatefulWidget {
  const PaymentSupportPage({super.key, required this.args});

  final PaymentSupportArgs args;

  @override
  ConsumerState<PaymentSupportPage> createState() => _PaymentSupportPageState();
}

class _PaymentSupportPageState extends ConsumerState<PaymentSupportPage> {
  final _message = TextEditingController();
  final _reference = TextEditingController();
  var _loading = true;
  var _sending = false;
  var _received = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final note = await ref
          .read(otpPrintControllerProvider.notifier)
          .loadSupportNote(widget.args.challengeId);
      if (!mounted) return;
      setState(() {
        _received = note != null;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'payment_already_settled') {
        await Navigator.of(context).pushReplacementNamed(AppRoutes.otpPrintSuccess);
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(otpPrintControllerProvider.notifier).sendSupportNote(
            challengeId: widget.args.challengeId,
            message: text,
            paymentReference: _reference.text,
          );
      if (!mounted) return;
      setState(() {
        _received = true;
        _sending = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'payment_already_settled') {
        await Navigator.of(context).pushReplacementNamed(AppRoutes.otpPrintSuccess);
        return;
      }
      setState(() {
        _error = error.message;
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderId = widget.args.orderId;
    return SkpScaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SkpPageHeader(
                  title: 'Contact support',
                  subtitle: 'Tell us what happened. We already have this payment.',
                  showBack: true,
                ),
                const SizedBox(height: 24),
                SkpPanelCard(
                  child: Column(
                    children: [
                      _row(theme, 'Amount', widget.args.amountLabel),
                      _row(theme, 'Kiosk', widget.args.kioskName),
                      _row(
                        theme,
                        'Order',
                        orderId == null || orderId.isEmpty ? 'Not available yet' : orderId,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_received)
                  Text(
                    'We received this. Check your SMS before paying again.',
                    style: theme.textTheme.titleMedium,
                  )
                else ...[
                  TextField(
                    controller: _message,
                    enabled: !_sending,
                    maxLength: 500,
                    minLines: 4,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'What happened',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reference,
                    enabled: !_sending,
                    maxLength: 80,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'UPI or bank reference',
                      helperText: 'Optional',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    SkpStatusBanner(message: _error!, tone: SkpBannerTone.danger),
                  ],
                  const SizedBox(height: 16),
                  SkpPrimaryButton(
                    label: 'Send',
                    loading: _sending,
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: SkpColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
