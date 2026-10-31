import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/core/format.dart';
import 'package:skp_admin/core/theme/app_theme.dart';
import 'package:skp_admin/core/ui/widgets.dart';
import 'package:skp_admin/features/fleet/presentation/fleet_controller.dart';
import 'package:skp_admin/features/print_jobs/presentation/print_jobs_controller.dart';

class PrintJobsPage extends ConsumerWidget {
  const PrintJobsPage({super.key, this.deviceId, this.deviceName});

  final String? deviceId;
  final String? deviceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(printJobsProvider);
    final fleet = ref.watch(fleetProvider);
    final names = {for (final device in fleet.devices) device.id: device.name};
    final visible = deviceId == null
        ? jobs.items
        : jobs.items.where((job) => job.deviceId == deviceId).toList();

    return Scaffold(
      appBar: AppBar(title: Text(deviceName == null ? 'Print jobs' : 'Jobs · $deviceName')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(printJobsProvider.notifier).load(),
        child: jobs.loading && jobs.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (jobs.error != null) ErrorBanner(message: jobs.error!),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No print jobs yet.',
                        style: TextStyle(color: AdminColors.muted),
                      ),
                    )
                  else
                    ...visible.map(
                      (job) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(job.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  printSourceLabel(job.source),
                                  job.printColorMode == 'color' ? 'Color' : 'B/W',
                                  if (deviceId == null && job.deviceId != null)
                                    names[job.deviceId] ?? 'Kiosk',
                                ].join(' · '),
                                style: const TextStyle(color: AdminColors.muted),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  StatusChip(status: job.status),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatTimestamp(job.createdAt),
                                    style: const TextStyle(color: AdminColors.muted),
                                  ),
                                ],
                              ),
                              if (job.needsAdminReview) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Needs review',
                                  style: TextStyle(color: AdminColors.warning, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
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
