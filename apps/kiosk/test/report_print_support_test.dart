import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/services/print_spooler.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';
import 'package:skp_kiosk/services/printer/printer_monitor.dart';
import 'package:skp_kiosk/services/printer/printer_native.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

class _FailingApiClient extends ApiClient {
  _FailingApiClient()
      : super(
          config: const AppConfig(
            apiBaseUrl: 'http://localhost/v1',
            environment: 'test',
          ),
        );

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    throw ApiException(
      code: 'payload_too_large',
      message: 'Request body too large',
    );
  }
}

class _NoopSpooler implements PrintSpooler {
  @override
  Future<void> printDocument({
    required String jobId,
    required String title,
    String? payloadUrl,
    String? filePath,
    Uint8List? pdfBytes,
    String colorMode = 'color',
  }) async {}
}

void main() {
  test('prepare failure returns printResult not idle', () async {
    final support = ReportPrintSupport(
      api: _FailingApiClient(),
      coordinator: PrintCoordinator(
        spooler: _NoopSpooler(),
        monitor: PrinterMonitor(
          native: FakePrinterNative(),
          config: const AppConfig(
            apiBaseUrl: 'http://localhost/v1',
            environment: 'test',
          ),
        ),
      ),
    );
    final next = await support.prepare(
      createJobPath: '/astrology/kundali/print',
      body: {'subject': 'x'},
    );
    expect(next.phase, ReportPrintPhase.printResult);
    expect(next.printConfirmed, isFalse);
    expect(next.previewBytes, isNull);
    expect(next.error, isNotNull);
    expect(next.message, isNotNull);
    expect(next.isActive, isTrue);
  });

  test('ReportPrintSnapshot copyWith clears and updates fields', () {
    const base = ReportPrintSnapshot(
      phase: ReportPrintPhase.previewing,
      previewTitle: 'Health Report',
      previewJobId: 'job-1',
      previewBytes: null,
      printFailures: 1,
      error: 'failed once',
    );

    final next = base.copyWith(
      phase: ReportPrintPhase.printing,
      clearError: true,
      message: 'Spooling…',
    );

    expect(next.phase, ReportPrintPhase.printing);
    expect(next.error, isNull);
    expect(next.message, 'Spooling…');
    expect(next.printFailures, 1);
    expect(next.previewJobId, 'job-1');
    expect(next.isActive, isTrue);
  });

  test('idle snapshot is inactive', () {
    expect(const ReportPrintSnapshot().isActive, isFalse);
    expect(
      const ReportPrintSnapshot(phase: ReportPrintPhase.printResult).isActive,
      isTrue,
    );
  });

  test('preview bytes can be retained across copyWith', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final snap = ReportPrintSnapshot(
      phase: ReportPrintPhase.previewing,
      previewBytes: bytes,
      previewJobId: 'abc',
    );
    final next = snap.copyWith(phase: ReportPrintPhase.printing);
    expect(next.previewBytes, same(bytes));
  });
}
