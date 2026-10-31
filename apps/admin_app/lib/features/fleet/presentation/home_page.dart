import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/core/theme/app_theme.dart';
import 'package:skp_admin/core/ui/widgets.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/fleet/presentation/fleet_controller.dart';
import 'package:skp_admin/features/fleet/presentation/kiosk_card.dart';
import 'package:skp_admin/features/printer/presentation/printer_page.dart';
import 'package:skp_admin/features/support/presentation/support_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleet = ref.watch(fleetProvider);
    final support = ref.watch(supportProvider);
    final auth = ref.watch(staffAuthProvider);
    final attention = fleet.attention;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(staffAuthProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(fleetProvider.notifier).load();
          await ref.read(supportProvider.notifier).load();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (fleet.error != null) ErrorBanner(message: fleet.error!),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Need attention',
                    value: fleet.loading ? '…' : '${attention.length}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Open support',
                    value: support.loading && support.items.isEmpty ? '…' : '${support.openCount}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Needs attention', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (fleet.loading && fleet.devices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (attention.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'All kiosks are reporting normally.',
                  style: TextStyle(color: AdminColors.muted),
                ),
              )
            else
              ...attention.map(
                (device) => KioskCard(
                  device: device,
                  canWrite: auth.canWrite,
                  submitting: fleet.submitting,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PrinterPage(deviceId: device.id)),
                    );
                  },
                  onSetStatus: (status) {
                    ref.read(fleetProvider.notifier).setStatus(device, status);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AdminColors.muted)),
          ],
        ),
      ),
    );
  }
}
