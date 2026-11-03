import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/services/printer/report_print_support.dart';

void main() {
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
