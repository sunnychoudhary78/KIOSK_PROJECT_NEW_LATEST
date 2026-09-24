import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/ui/kiosk_pdf_preview.dart';

/// Kept for existing imports; chrome now lives on [DigilockerPrintPage].
class DigilockerPdfPreviewPage extends StatelessWidget {
  const DigilockerPdfPreviewPage({
    super.key,
    required this.title,
    required this.pdfBytes,
    required this.onBack,
    required this.onPrint,
    required this.onDone,
    this.printing = false,
    this.error,
  });

  final String title;
  final Uint8List pdfBytes;
  final VoidCallback onBack;
  final VoidCallback onPrint;
  final VoidCallback onDone;
  final bool printing;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return KioskPdfPreview(
      title: title,
      pdfBytes: pdfBytes,
      error: error,
    );
  }
}
