import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/features/surveillance/application/surveillance_controller.dart';
import 'package:skp_kiosk/features/surveillance/application/surveillance_health.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_uploader.dart';

/// Discreet header chip showing live surveillance health when enabled.
class SurveillanceStatusChip extends ConsumerWidget {
  const SurveillanceStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(deviceAuthProvider);
    if (!auth.isAuthenticated || !auth.surveillanceEnabled) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(surveillanceControllerProvider);
    final queue = ref.watch(surveillanceUploadSinkProvider).queueStats();
    final health = resolveSurveillanceHealth(
      enabled: true,
      state: state,
      queue: queue,
    );

    final (icon, color, label) = switch (health) {
      SurveillanceHealthState.recording => (
          Icons.videocam,
          const Color(0xFF2F9E6B),
          'Recording',
        ),
      SurveillanceHealthState.uploading => (
          Icons.cloud_upload_outlined,
          SkpColors.gold,
          'Uploading ${queue.pendingCount}',
        ),
      SurveillanceHealthState.pausedPalm => (
          Icons.pause_circle_outline,
          SkpColors.muted,
          'Paused',
        ),
      SurveillanceHealthState.cameraError => (
          Icons.videocam_off,
          SkpColors.danger,
          'Camera error',
        ),
      SurveillanceHealthState.storageLow => (
          Icons.sd_card_alert_outlined,
          SkpColors.danger,
          'Storage low',
        ),
      SurveillanceHealthState.stale => (
          Icons.videocam_outlined,
          SkpColors.gold,
          'Starting…',
        ),
      _ => (
          Icons.videocam_outlined,
          SkpColors.muted,
          'Surveillance',
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: [
          if (state.lastSegmentAt != null)
            'Last clip: ${state.lastSegmentAt!.toLocal()}',
          if (queue.pendingCount > 0) 'Pending upload: ${queue.pendingCount}',
          if (queue.failedCount > 0) 'Failed: ${queue.failedCount}',
          if (state.error != null) 'Error: ${state.error}',
        ].where((line) => line.isNotEmpty).join('\n'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
