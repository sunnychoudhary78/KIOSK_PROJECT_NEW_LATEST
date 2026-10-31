import 'package:flutter/material.dart';
import 'package:skp_admin/core/format.dart';
import 'package:skp_admin/core/theme/app_theme.dart';
import 'package:skp_admin/features/printer/data/printer_display.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' || 'completed' || 'ready' || 'resolved' || 'verified' => AdminColors.success,
      'failed' || 'expired' || 'inactive' || 'error' => AdminColors.danger,
      'printing' || 'created' || 'open' => AdminColors.accent,
      _ => AdminColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ToneText extends StatelessWidget {
  const ToneText({super.key, required this.label, required this.tone});

  final String label;
  final PrinterRowTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      PrinterRowTone.ok => AdminColors.success,
      PrinterRowTone.amber => AdminColors.warning,
      PrinterRowTone.alert => AdminColors.danger,
      PrinterRowTone.muted => AdminColors.muted,
    };
    return Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(message, style: const TextStyle(color: AdminColors.danger)),
    );
  }
}
