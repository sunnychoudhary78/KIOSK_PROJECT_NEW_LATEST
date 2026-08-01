import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/features/otp_print/application/otp_print_controller.dart';

class OtpPrintPage extends ConsumerStatefulWidget {
  const OtpPrintPage({super.key});

  @override
  ConsumerState<OtpPrintPage> createState() => _OtpPrintPageState();
}

class _OtpPrintPageState extends ConsumerState<OtpPrintPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpPrintControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('OTP Print')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the OTP from the mobile app / SMS',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'OTP',
              ),
              onSubmitted: (value) {
                if (!state.isLoading && value.trim().isNotEmpty) {
                  ref.read(otpPrintControllerProvider.notifier).redeemAndPrint(value.trim());
                }
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state.isLoading
                  ? null
                  : () => ref
                      .read(otpPrintControllerProvider.notifier)
                      .redeemAndPrint(_controller.text.trim()),
              child: Text(state.isLoading ? 'Printing…' : 'Redeem & print'),
            ),
            const SizedBox(height: 16),
            state.when(
              data: (result) {
                if (result == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Printed: ${result.title}'),
                    const SizedBox(height: 8),
                    ...result.documents.map(
                      (doc) => Text('• ${doc.fileName} (${doc.pageCount} page(s))'),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
