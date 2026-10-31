import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:skp_kiosk/services/print_spooler.dart';
import 'package:skp_kiosk/services/printer/printer_native.dart';

Printer _printer(String name) {
  return Printer(url: name, name: name);
}

void main() {
  const usbName = 'Brother HL-L3280CDW series';
  const wifiName = 'Brother HL-L3280CDW series (Wi-Fi)';

  test('matchResolvedPrinter uses the USB queue name, not another Brother queue', () {
    final chosen = matchResolvedPrinter(
      [_printer(wifiName), _printer(usbName)],
      usbName,
    );
    expect(chosen.name, usbName);
  });

  test('matchResolvedPrinter fails when the resolved name is absent', () {
    expect(
      () => matchResolvedPrinter([_printer(wifiName)], usbName),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(usbName),
        ),
      ),
    );
  });

  test('printDocument sends only the resolved USB queue', () async {
    Printer? sent;
    final spooler = WindowsPdfPrintSpooler(
      reversePages: false,
      resolveUsbPrinter: () async => const UsbPrinterResolution(
        found: true,
        name: usbName,
        port: 'USB001',
      ),
      listPrinters: () async => [_printer(wifiName), _printer(usbName)],
      directPrint: ({
        required Printer printer,
        required String name,
        required Uint8List bytes,
      }) async {
        sent = printer;
        return true;
      },
    );

    await spooler.printDocument(
      jobId: 'job-1',
      title: 'page',
      pdfBytes: Uint8List.fromList([1, 2, 3]),
      colorMode: 'color',
    );

    expect(sent?.name, usbName);
  });

  test('printDocument does not send when no USB queue is resolved', () async {
    var sent = false;
    final spooler = WindowsPdfPrintSpooler(
      reversePages: false,
      resolveUsbPrinter: () async => const UsbPrinterResolution(found: false),
      listPrinters: () async => [_printer(wifiName)],
      directPrint: ({
        required Printer printer,
        required String name,
        required Uint8List bytes,
      }) async {
        sent = true;
        return true;
      },
    );

    await expectLater(
      spooler.printDocument(
        jobId: 'job-1',
        title: 'page',
        pdfBytes: Uint8List.fromList([1, 2, 3]),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('USB printer was not found'),
        ),
      ),
    );
    expect(sent, isFalse);
  });
}
