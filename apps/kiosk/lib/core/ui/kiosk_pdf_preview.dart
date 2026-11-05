import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
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
                // Isolated so message/error rebuilds cannot remount PdfPreview.
                child: _StablePdfPreview(
                  title: title,
                  pdfBytes: pdfBytes,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Caches [PdfPreview] so parent rebuilds (progress text) do not re-raster.
class _StablePdfPreview extends StatefulWidget {
  const _StablePdfPreview({
    required this.title,
    required this.pdfBytes,
  });

  final String title;
  final Uint8List pdfBytes;

  @override
  State<_StablePdfPreview> createState() => _StablePdfPreviewState();
}

class _StablePdfPreviewState extends State<_StablePdfPreview> {
  late Widget _viewer;

  @override
  void initState() {
    super.initState();
    _viewer = _createViewer();
  }

  @override
  void didUpdateWidget(covariant _StablePdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bytesChanged = !identical(oldWidget.pdfBytes, widget.pdfBytes) ||
        oldWidget.pdfBytes.length != widget.pdfBytes.length;
    final titleChanged = oldWidget.title != widget.title;
    if (bytesChanged || titleChanged) {
      _viewer = _createViewer();
    }
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async => widget.pdfBytes;

  Widget _createViewer() {
    return PdfPreview(
      key: ValueKey<Object>(
        Object.hash(identityHashCode(widget.pdfBytes), widget.title),
      ),
      build: _buildPdf,
      pdfFileName: '${widget.title}.pdf',
      allowPrinting: false,
      allowSharing: false,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      actions: const [],
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) => _viewer;
}
