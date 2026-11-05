import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:skp_kiosk/core/ui/kiosk_pdf_preview.dart';

/// Minimal valid PDF (empty page) for widget tests.
Uint8List _minimalPdf() {
  const raw = '%PDF-1.4\n'
      '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
      '2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n'
      '3 0 obj<</Type/Page/MediaBox[0 0 200 200]/Parent 2 0 R>>endobj\n'
      'xref\n0 4\n0000000000 65535 f \n'
      '0000000009 00000 n \n0000000052 00000 n \n0000000101 00000 n \n'
      'trailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF\n';
  return Uint8List.fromList(raw.codeUnits);
}

class _PreviewHarness extends StatefulWidget {
  const _PreviewHarness({
    required this.pdfBytes,
    required this.initialMessage,
  });

  final Uint8List pdfBytes;
  final String initialMessage;

  @override
  State<_PreviewHarness> createState() => _PreviewHarnessState();
}

class _PreviewHarnessState extends State<_PreviewHarness> {
  late String message = widget.initialMessage;
  late Uint8List pdfBytes = widget.pdfBytes;

  void setMessage(String value) => setState(() => message = value);

  void setPdfBytes(Uint8List value) => setState(() => pdfBytes = value);

  @override
  Widget build(BuildContext context) {
    return KioskPdfPreview(
      title: 'doc',
      pdfBytes: pdfBytes,
      message: message,
    );
  }
}

void main() {
  testWidgets('message-only rebuild does not remount PdfPreview', (tester) async {
    final bytes = _minimalPdf();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _PreviewHarness(
            pdfBytes: bytes,
            initialMessage: 'Printing…',
          ),
        ),
      ),
    );
    await tester.pump();

    final first = tester.element(find.byType(PdfPreview));
    final firstKey = tester.widget<PdfPreview>(find.byType(PdfPreview)).key;

    final harness = tester.state<_PreviewHarnessState>(find.byType(_PreviewHarness));
    harness.setMessage('Confirming print…');
    await tester.pump();

    final second = tester.element(find.byType(PdfPreview));
    final secondKey = tester.widget<PdfPreview>(find.byType(PdfPreview)).key;

    expect(identical(first, second), isTrue);
    expect(firstKey, same(secondKey));
    expect(find.text('Confirming print…'), findsOneWidget);
  });

  testWidgets('new pdfBytes remounts PdfPreview', (tester) async {
    final firstBytes = _minimalPdf();
    final secondBytes = Uint8List.fromList(firstBytes);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _PreviewHarness(
            pdfBytes: firstBytes,
            initialMessage: 'A',
          ),
        ),
      ),
    );
    await tester.pump();
    final firstKey = tester.widget<PdfPreview>(find.byType(PdfPreview)).key;

    final harness = tester.state<_PreviewHarnessState>(find.byType(_PreviewHarness));
    harness.setPdfBytes(secondBytes);
    await tester.pump();
    final secondKey = tester.widget<PdfPreview>(find.byType(PdfPreview)).key;

    expect(firstKey, isNot(equals(secondKey)));
  });
}
