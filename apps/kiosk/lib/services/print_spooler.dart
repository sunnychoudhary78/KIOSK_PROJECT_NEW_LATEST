import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/services/printer/printer_monitor.dart';
import 'package:skp_kiosk/services/printer/printer_native.dart';

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
  final native = ref.watch(printerNativeProvider);
  return WindowsPdfPrintSpooler(
    reversePages: config.printReversePages,
    resolveUsbPrinter: () =>
        native.resolveUsbPrinter(printerName: config.printerName),
  );
});

/// Picks the Windows queue named by a USB resolution. Substring matches are ignored.
Printer matchResolvedPrinter(List<Printer> printers, String resolvedName) {
  final needle = resolvedName.trim().toLowerCase();
  if (needle.isEmpty) {
    throw StateError(
      'USB printer was not found. Check the USB cable and that the Brother queue uses a USB port.',
    );
  }
  final matches = printers
      .where((printer) => printer.name.toLowerCase() == needle)
      .toList(growable: false);
  if (matches.isEmpty) {
    throw StateError(
      'USB printer "$resolvedName" is not available. '
      'Available: ${printers.map((printer) => '"${printer.name}"').join(', ')}',
    );
  }
  return matches.first;
}

/// Silent PDF print via the Flutter `printing` package (Windows spooler).
class WindowsPdfPrintSpooler implements PrintSpooler {
  WindowsPdfPrintSpooler({
    required this.resolveUsbPrinter,
    this.reversePages = true,
    this.listPrinters,
    this.directPrint,
  });

  /// Native lookup of the Brother queue whose port starts with USB.
  final Future<UsbPrinterResolution> Function() resolveUsbPrinter;

  /// Print last page first so face-up output trays stack with page 1 on top.
  final bool reversePages;

  /// Override for tests. Production uses [Printing.listPrinters].
  final Future<List<Printer>> Function()? listPrinters;

  /// Override for tests. Production uses [Printing.directPrintPdf].
  final Future<bool> Function({
    required Printer printer,
    required String name,
    required Uint8List bytes,
  })? directPrint;

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

    final target = await _resolvePrinter();
    final printer = target.printer;
    final grayscale = colorMode == 'bw';
    final layoutBytes = (reversePages || grayscale)
        ? await _layoutPdfPages(bytes, grayscale: grayscale)
        : bytes;
    debugPrint(
      '[PrintSpooler] job=$jobId → "${printer.name}" port=${target.port} '
      '(default=${printer.isDefault}, reversePages=$reversePages, '
      'colorMode=$colorMode)',
    );

    // Request A4 explicitly so the Windows job matches the cassette
    // registration (avoids paper-mismatch dialogs).
    final send = directPrint;
    final ok = send != null
        ? await send(printer: printer, name: title, bytes: layoutBytes)
        : await Printing.directPrintPdf(
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

  Future<({Printer printer, String port})> _resolvePrinter() async {
    final resolved = await resolveUsbPrinter();
    if (!resolved.found || resolved.name.trim().isEmpty) {
      throw StateError(
        'USB printer was not found. Check the USB cable and that the Brother queue uses a USB port.',
      );
    }
    final printers = await (listPrinters ?? Printing.listPrinters)();
    return (
      printer: matchResolvedPrinter(printers, resolved.name),
      port: resolved.port,
    );
  }
}
