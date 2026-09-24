import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:skp_kiosk/core/config/app_config.dart';

/// Local print spooler adapter for Windows kiosk PDF printing.
abstract class PrintSpooler {
  Future<void> printDocument({
    required String jobId,
    required String title,
    String? payloadUrl,
    String? filePath,
    Uint8List? pdfBytes,
    String colorMode = 'color',
  });
}

final printSpoolerProvider = Provider<PrintSpooler>((ref) {
  final config = AppConfig.fromEnvironment();
  return WindowsPdfPrintSpooler(
    preferredPrinterName: config.printerName,
    reversePages: config.printReversePages,
  );
});

/// Silent PDF print via the Flutter `printing` package (Windows spooler).
class WindowsPdfPrintSpooler implements PrintSpooler {
  WindowsPdfPrintSpooler({
    this.preferredPrinterName = '',
    this.reversePages = true,
  });

  /// Case-insensitive substring of the Windows printer name.
  final String preferredPrinterName;

  /// Print last page first so face-up output trays stack with page 1 on top.
  final bool reversePages;

  @override
  Future<void> printDocument({
    required String jobId,
    required String title,
    String? payloadUrl,
    String? filePath,
    Uint8List? pdfBytes,
    String colorMode = 'color',
  }) async {
    final bytes = pdfBytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('No PDF bytes available to print.');
    }

    final printer = await _resolvePrinter();
    final grayscale = colorMode == 'bw';
    final layoutBytes = (reversePages || grayscale)
        ? await _layoutPdfPages(bytes, grayscale: grayscale)
        : bytes;
    debugPrint(
      '[PrintSpooler] job=$jobId → "${printer.name}" '
      '(default=${printer.isDefault}, reversePages=$reversePages, '
      'colorMode=$colorMode)',
    );

    // Request A4 explicitly so the Windows job matches typical Canon cassette
    // registration (avoids Support Code 2113 paper-mismatch dialogs).
    final ok = await Printing.directPrintPdf(
      printer: printer,
      name: title,
      format: PdfPageFormat.a4,
      usePrinterSettings: false,
      onLayout: (_) async => layoutBytes,
    );
    if (!ok) {
      throw StateError(
        'Print was rejected by Windows for "${printer.name}". Check the printer queue and try again.',
      );
    }
  }

  /// Rebuild PDF with optional reverse order and grayscale conversion.
  Future<Uint8List> _layoutPdfPages(
    Uint8List input, {
    required bool grayscale,
  }) async {
    const dpi = 200.0;
    final rasters = await Printing.raster(input, dpi: dpi).toList();
    if (rasters.isEmpty) {
      return input;
    }
    if (!grayscale && rasters.length <= 1) {
      return input;
    }

    final pages = reversePages && rasters.length > 1
        ? rasters.reversed
        : rasters;

    final doc = pw.Document();
    for (final page in pages) {
      var png = await page.toPng();
      if (grayscale) {
        png = _toGrayscalePng(png);
      }
      final image = pw.MemoryImage(png);
      final width = page.width * PdfPageFormat.inch / dpi;
      final height = page.height * PdfPageFormat.inch / dpi;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(width, height, marginAll: 0),
          build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
        ),
      );
    }
    return Uint8List.fromList(await doc.save());
  }

  Uint8List _toGrayscalePng(Uint8List png) {
    final decoded = img.decodePng(png);
    if (decoded == null) {
      return png;
    }
    img.grayscale(decoded);
    return Uint8List.fromList(img.encodePng(decoded));
  }

  Future<Printer> _resolvePrinter() async {
    final printers = await Printing.listPrinters();
    if (printers.isEmpty) {
      throw StateError(
        'No printer available. Install and connect a Windows printer (e.g. Canon), then try Print again.',
      );
    }

    final preferred = preferredPrinterName.trim();
    if (preferred.isNotEmpty) {
      final needle = preferred.toLowerCase();
      final matches = printers
          .where((p) => p.name.toLowerCase().contains(needle))
          .toList(growable: false);
      if (matches.isEmpty) {
        throw StateError(
          'Printer "$preferred" not found. Available: ${_formatNames(printers)}',
        );
      }
      final exact = matches.where((p) => p.name.toLowerCase() == needle);
      if (exact.isNotEmpty) return exact.first;
      final defaultMatch = matches.where((p) => p.isDefault);
      if (defaultMatch.isNotEmpty) return defaultMatch.first;
      return matches.first;
    }

    final defaults = printers.where((p) => p.isDefault).toList(growable: false);
    if (defaults.isNotEmpty) {
      return defaults.first;
    }

    if (printers.length == 1) {
      return printers.first;
    }

    throw StateError(
      'Multiple printers installed and none is the Windows default. '
      'Set a default printer, or launch with '
      '--dart-define=SKP_PRINTER_NAME=<name>. Available: ${_formatNames(printers)}',
    );
  }

  String _formatNames(List<Printer> printers) =>
      printers.map((p) => '"${p.name}"').join(', ');
}
