import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// In-app PDF preview for an OTP-print document before optional print.
class OtpPdfPreviewPage extends StatelessWidget {
  const OtpPdfPreviewPage({
    super.key,
    required this.title,
    required this.pdfBytes,
    required this.onBack,
    required this.onPrint,
    required this.onDone,
    this.printing = false,
    this.error,
    this.message,
  });

  final String title;
  final Uint8List pdfBytes;
  final VoidCallback onBack;
  final VoidCallback onPrint;
  final VoidCallback onDone;
  final bool printing;
  final String? error;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: printing ? null : onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton.tonal(
                onPressed: printing ? null : onDone,
                child: const Text('Done'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: printing ? null : onPrint,
                icon: printing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print),
                label: Text(printing ? 'Printing…' : 'Print'),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(message!),
          ),
        Expanded(
          child: PdfPreview(
            build: (format) async => pdfBytes,
            pdfFileName: '$title.pdf',
            allowPrinting: false,
            allowSharing: false,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            actions: const [],
          ),
        ),
      ],
    );
  }
}
