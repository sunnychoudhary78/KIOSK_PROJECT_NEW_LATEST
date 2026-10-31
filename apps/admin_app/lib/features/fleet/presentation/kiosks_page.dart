import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/core/theme/app_theme.dart';
import 'package:skp_admin/core/ui/widgets.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/fleet/presentation/fleet_controller.dart';
import 'package:skp_admin/features/fleet/presentation/kiosk_card.dart';
import 'package:skp_admin/features/printer/presentation/printer_page.dart';

class KiosksPage extends ConsumerWidget {
  const KiosksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleet = ref.watch(fleetProvider);
    final canWrite = ref.watch(staffAuthProvider).canWrite;

    return Scaffold(
      appBar: AppBar(title: const Text('Kiosks')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(fleetProvider.notifier).load(),
        child: fleet.loading && fleet.devices.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (fleet.error != null) ErrorBanner(message: fleet.error!),
                  if (fleet.devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No kiosks registered yet. Register one from the web panel.',
                        style: TextStyle(color: AdminColors.muted),
                      ),
                    )
                  else
                    ...fleet.devices.map(
                      (device) => KioskCard(
                        device: device,
                        canWrite: canWrite,
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
