import 'package:flutter/material.dart';
import 'package:skp_admin/core/format.dart';
import 'package:skp_admin/core/theme/app_theme.dart';
import 'package:skp_admin/core/ui/widgets.dart';
import 'package:skp_admin/features/fleet/data/device.dart';
import 'package:skp_admin/features/printer/data/printer_display.dart';

class KioskCard extends StatelessWidget {
  const KioskCard({
    super.key,
    required this.device,
    required this.canWrite,
    required this.submitting,
    required this.onOpen,
    required this.onSetStatus,
  });

  final KioskDevice device;
  final bool canWrite;
  final bool submitting;
  final VoidCallback onOpen;
  final ValueChanged<String> onSetStatus;

  @override
  Widget build(BuildContext context) {
    final summary = resolvePrinterRowSummary(device.printerHealth);
    final recording = resolveRecordingDisplay(device);
    final paused = device.printingPausedReason;
    final nextStatus = device.status == 'inactive' ? 'active' : 'inactive';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      device.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusChip(status: device.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${device.siteName} · ${device.locationLabel}',
                style: const TextStyle(color: AdminColors.muted),
              ),
              const SizedBox(height: 10),
              ToneText(label: summary.label, tone: summary.tone),
              const SizedBox(height: 4),
              Text(
                'Pages left ${device.pagesLeft ?? '—'} · ${formatTimestamp(device.lastHeartbeatAt)}',
                style: const TextStyle(color: AdminColors.muted),
              ),
              const SizedBox(height: 4),
              ToneText(label: recording.label, tone: recording.tone),
              if (paused != null && paused.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Printing paused',
                  style: TextStyle(color: AdminColors.danger, fontWeight: FontWeight.w600),
                ),
              ],
              if (canWrite) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: submitting ? null : () => onSetStatus(nextStatus),
                    child: Text(nextStatus == 'active' ? 'Start' : 'Stop'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
