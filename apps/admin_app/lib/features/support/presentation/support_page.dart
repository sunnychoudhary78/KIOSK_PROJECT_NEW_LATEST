import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/core/format.dart';
import 'package:skp_admin/core/theme/app_theme.dart';
import 'package:skp_admin/core/ui/widgets.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/support/presentation/support_controller.dart';

const supportResolutions = <String, String>{
  'no_action': 'No action needed',
  'reprinted': 'Reprinted',
  'refunded': 'Refunded',
};

String resolutionLabel(String value) {
  return switch (value) {
    'otp_sent' => 'OTP sent',
    'session_ready' => 'Session ready',
    _ => supportResolutions[value] ?? statusLabel(value),
  };
}

class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(supportProvider);
    final visible = support.visible;

    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(supportProvider.notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterMenu(
                  value: support.status,
                  items: const {'open': 'Open', 'resolved': 'Resolved', 'all': 'All statuses'},
                  onChanged: (value) => ref.read(supportProvider.notifier).setStatusFilter(value),
                ),
                _FilterMenu(
                  value: support.source,
                  items: const {'all': 'All sources', 'payment': 'Payment', 'print': 'Print'},
                  onChanged: (value) => ref.read(supportProvider.notifier).setSourceFilter(value),
                ),
                _FilterMenu(
                  value: support.kioskNames.contains(support.kiosk) ? support.kiosk : 'all',
                  items: {'all': 'All kiosks', for (final name in support.kioskNames) name: name},
                  onChanged: (value) => ref.read(supportProvider.notifier).setKioskFilter(value),
                ),
              ],
            ),
            if (support.error != null) ErrorBanner(message: support.error!),
            const SizedBox(height: 12),
            if (support.loading && support.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visible.isEmpty)
              const Text(
                'No support messages.',
                style: TextStyle(color: AdminColors.muted),
              )
            else
              ...visible.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SupportDetailPage(queryId: item.id)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.source == 'print' ? 'Print' : 'Payment',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              StatusChip(status: item.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.kioskName?.isNotEmpty == true ? item.kioskName : '—'} · ${formatTimestamp(item.createdAt)}',
                            style: const TextStyle(color: AdminColors.muted),
                          ),
                          const SizedBox(height: 8),
                          Text(item.message, maxLines: 3, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SupportDetailPage extends ConsumerStatefulWidget {
  const SupportDetailPage({super.key, required this.queryId});

  final String queryId;

  @override
  ConsumerState<SupportDetailPage> createState() => _SupportDetailPageState();
}

class _SupportDetailPageState extends ConsumerState<SupportDetailPage> {
  var _resolution = 'no_action';

  @override
  Widget build(BuildContext context) {
    final support = ref.watch(supportProvider);
    final query = support.byId(widget.queryId);
    final canWrite = ref.watch(staffAuthProvider).canWrite;

    if (query == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Message')),
        body: const Center(child: Text('This message is no longer in the list.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Message')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(query.message),
          const SizedBox(height: 16),
          _line('Kiosk', query.kioskName?.isNotEmpty == true ? query.kioskName! : '—'),
          _line('Phone', query.phone.isEmpty ? '—' : query.phone),
          _line(
            'Amount',
            query.amountPaise == 0 && (query.razorpayOrderId == null || query.razorpayOrderId!.isEmpty)
                ? '—'
                : formatRupees(query.amountPaise),
          ),
          if (query.paymentStatus != null) _line('Payment', statusLabel(query.paymentStatus!)),
          if (query.failureReason != null && query.failureReason!.isNotEmpty)
            _line('Failure', query.failureReason!),
          if (query.razorpayOrderId != null && query.razorpayOrderId!.isNotEmpty)
            _line('Order', query.razorpayOrderId!),
          if (query.paymentReference != null && query.paymentReference!.isNotEmpty)
            _line('Payment reference', query.paymentReference!),
          if (query.printJobId != null)
            _line(
              'Print job',
              [
                query.printJobStatus ?? '—',
                if (query.pagesExpected != null)
                  '${query.pagesReported ?? '—'}/${query.pagesExpected} pages',
                if (query.printJobError != null && query.printJobError!.isNotEmpty) query.printJobError!,
              ].join(' · '),
            ),
          if (query.resolution != null && query.resolution!.isNotEmpty)
            _line('Outcome', resolutionLabel(query.resolution!)),
          if (support.error != null) ...[
            const SizedBox(height: 12),
            Text(support.error!, style: const TextStyle(color: AdminColors.danger)),
          ],
          if (canWrite && query.status == 'open') ...[
            const SizedBox(height: 20),
            if (query.canResendOtp)
              OutlinedButton(
                onPressed: support.acting
                    ? null
                    : () => ref.read(supportProvider.notifier).resendOtp(query.id),
                child: Text(support.acting ? 'Working…' : 'Resend OTP'),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _resolution,
              decoration: const InputDecoration(labelText: 'Outcome'),
              items: [
                for (final entry in supportResolutions.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: support.acting
                  ? null
                  : (value) {
                      if (value != null) setState(() => _resolution = value);
                    },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: support.acting
                  ? null
                  : () => ref.read(supportProvider.notifier).resolve(query.id, _resolution),
              child: Text(support.acting ? 'Saving…' : 'Mark resolved'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AdminColors.muted),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: items.containsKey(value) ? value : items.keys.first,
      items: [
        for (final entry in items.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}
