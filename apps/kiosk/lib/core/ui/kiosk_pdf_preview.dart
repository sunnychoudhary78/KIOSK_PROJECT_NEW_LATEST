import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

class KioskPdfPreview extends StatelessWidget {
  const KioskPdfPreview({
    super.key,
    required this.title,
    required this.pdfBytes,
    this.error,
    this.message,
  });

  final String title;
  final Uint8List pdfBytes;
  final String? error;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              error!,
              style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.danger),
            ),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(message!, style: theme.textTheme.titleMedium),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
              child: ColoredBox(
                color: SkpColors.raised,
                child: PdfPreview(
                  build: (format) async => pdfBytes,
                  pdfFileName: '$title.pdf',
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  actions: const [],
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
