import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Local print spooler adapter for Windows kiosk PDF printing.
abstract class PrintSpooler {
  Future<void> printDocument({
    required String jobId,
    required String title,
    String? payloadUrl,
    String? filePath,
    Uint8List? pdfBytes,
  });
}

/// Uses the Flutter `printing` package (no Adobe / external viewer).
class ConsolePrintSpooler implements PrintSpooler {
  @override
  Future<void> printDocument({
    required String jobId,
    required String title,
    String? payloadUrl,
    String? filePath,
    Uint8List? pdfBytes,
  }) async {
    final bytes = pdfBytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('No PDF bytes available to print.');
    }

    final printers = await Printing.listPrinters();
    if (printers.isEmpty) {
      throw StateError(
        'No printer available. Connect a printer, then try Print again.',
      );
    }

    final ok = await Printing.layoutPdf(
      name: title,
      onLayout: (_) async => bytes,
    );
    if (!ok) {
      throw StateError('Print was cancelled or failed.');
    }
  }
}
