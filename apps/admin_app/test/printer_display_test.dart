import 'package:flutter_test/flutter_test.dart';
import 'package:skp_admin/features/printer/data/printer_display.dart';
import 'package:skp_admin/features/printer/data/printer_health.dart';

const verified = PrinterHealth(
  snmpOk: true,
  lastSuccessAt: '2026-10-26T12:00:00.000Z',
  maintenance: PrinterMaintenance(
    available: true,
    toner: TonerLevels(
      blackPercent: 90,
      cyanPercent: 100,
      magentaPercent: 100,
      yellowPercent: 100,
    ),
    pages: PageCounts(total: 64, color: 47, blackAndWhite: 17),
    parts: PartLife(beltRemainingPages: 49882, fuserRemainingPages: 49936),
  ),
);

void main() {
  group('printer maintenance display', () {
    test('shows unavailable when maintenance was not read', () {
      expect(resolvePrinterMaintenance(null), isA<MaintenanceUnavailable>());
      expect(resolvePrinterMaintenance(const PrinterHealth()), isA<MaintenanceUnavailable>());
      expect(
        resolvePrinterMaintenance(
          const PrinterHealth(
            snmpOk: false,
            maintenance: PrinterMaintenance(available: false),
          ),
        ),
        isA<MaintenanceUnavailable>(),
      );
    });

    test('keeps the last numbers and marks them stale when SNMP is down', () {
      final display = resolvePrinterMaintenance(
        PrinterHealth(
          snmpOk: false,
          lastSuccessAt: verified.lastSuccessAt,
          maintenance: verified.maintenance,
        ),
      );
      expect(display, isA<MaintenanceShown>());
      final shown = display as MaintenanceShown;
      expect(shown.stale, isTrue);
      expect(shown.title, contains('Last successful printer poll'));
      expect(shown.lines.black, '90%');
      expect(shown.lines.total, '64');
      expect(shown.lines.belt, '49,882');
    });

    test('renders a reported zero and leaves a missing metric blank', () {
      final display = resolvePrinterMaintenance(
        const PrinterHealth(
          snmpOk: true,
          maintenance: PrinterMaintenance(
            available: true,
            toner: TonerLevels(blackPercent: 0),
            pages: PageCounts(total: 0, color: 47),
            parts: PartLife(fuserRemainingPages: 0),
          ),
        ),
      );
      final shown = display as MaintenanceShown;
      expect(shown.stale, isFalse);
      expect(shown.lines.black, '0%');
      expect(shown.lines.cyan, '—');
      expect(shown.lines.total, '0');
      expect(shown.lines.blackAndWhite, '—');
      expect(shown.lines.belt, '—');
      expect(shown.lines.fuser, '0');
    });

    test('does not show an out-of-range percent as a toner level', () {
      final display = resolvePrinterMaintenance(
        const PrinterHealth(
          snmpOk: true,
          maintenance: PrinterMaintenance(
            available: true,
            toner: TonerLevels(blackPercent: 101, cyanPercent: 90.5),
          ),
        ),
      );
      final shown = display as MaintenanceShown;
      expect(shown.lines.black, '—');
      expect(shown.lines.cyan, '—');
    });
  });

  group('printer error history display', () {
    test('shows unavailable when the walk has not succeeded', () {
      expect(resolvePrinterErrorHistory(null), isA<ErrorHistoryUnavailable>());
      expect(
        resolvePrinterErrorHistory(
          const PrinterHealth(errorHistory: PrinterErrorHistory(available: false)),
        ),
        isA<ErrorHistoryUnavailable>(),
      );
    });

    test('shows an empty successful walk instead of inventing errors', () {
      expect(
        resolvePrinterErrorHistory(
          const PrinterHealth(
            snmpOk: true,
            errorHistory: PrinterErrorHistory(available: true),
          ),
        ),
        isA<ErrorHistoryEmpty>(),
      );
    });

    test('shows the one non-empty description', () {
      final display = resolvePrinterErrorHistory(
        const PrinterHealth(
          snmpOk: true,
          errorHistory: PrinterErrorHistory(
            available: true,
            entries: [PrinterErrorEntry(index: 1, description: 'Cannot Print ZC')],
          ),
        ),
      );
      final shown = display as ErrorHistoryShown;
      expect(shown.stale, isFalse);
      expect(shown.entries, hasLength(1));
      expect(shown.entries.single.description, 'Cannot Print ZC');
    });

    test('marks a previous error list stale when SNMP is down', () {
      final display = resolvePrinterErrorHistory(
        const PrinterHealth(
          snmpOk: false,
          lastSuccessAt: '2026-10-26T12:00:00.000Z',
          errorHistory: PrinterErrorHistory(
            available: true,
            entries: [PrinterErrorEntry(index: 1, description: 'Cannot Print ZC')],
          ),
        ),
      );
      final shown = display as ErrorHistoryShown;
      expect(shown.stale, isTrue);
      expect(shown.entries.single.description, 'Cannot Print ZC');
      expect(shown.title, contains('Last successful printer poll'));
    });
  });

  group('printer row summary', () {
    test('shows unavailable when neither block was read', () {
      expect(resolvePrinterRowSummary(null).label, 'Unavailable');
      expect(resolvePrinterRowSummary(null).tone, PrinterRowTone.muted);
      expect(resolvePrinterRowSummary(const PrinterHealth()).label, 'Unavailable');
    });

    test('shows OK when maintenance is current and there are no recorded errors', () {
      final summary = resolvePrinterRowSummary(
        PrinterHealth(
          snmpOk: verified.snmpOk,
          lastSuccessAt: verified.lastSuccessAt,
          maintenance: verified.maintenance,
          errorHistory: const PrinterErrorHistory(available: true),
        ),
      );
      expect(summary.label, 'OK');
      expect(summary.tone, PrinterRowTone.ok);
    });

    test('shows Stale when SNMP is down and no errors are recorded', () {
      final summary = resolvePrinterRowSummary(
        PrinterHealth(
          snmpOk: false,
          lastSuccessAt: verified.lastSuccessAt,
          maintenance: verified.maintenance,
          errorHistory: const PrinterErrorHistory(available: true),
        ),
      );
      expect(summary.label, 'Stale');
      expect(summary.tone, PrinterRowTone.amber);
    });

    test('counts recorded errors and keeps a stale list amber', () {
      final current = resolvePrinterRowSummary(
        PrinterHealth(
          snmpOk: verified.snmpOk,
          maintenance: verified.maintenance,
          errorHistory: const PrinterErrorHistory(
            available: true,
            entries: [PrinterErrorEntry(index: 1, description: 'Cannot Print ZC')],
          ),
        ),
      );
      expect(current.label, '1 error');
      expect(current.tone, PrinterRowTone.alert);

      final stale = resolvePrinterRowSummary(
        PrinterHealth(
          snmpOk: false,
          maintenance: verified.maintenance,
          errorHistory: const PrinterErrorHistory(
            available: true,
            entries: [
              PrinterErrorEntry(index: 1, description: 'Cannot Print ZC'),
              PrinterErrorEntry(index: 2, description: 'Paper jam'),
            ],
          ),
        ),
      );
      expect(stale.label, '2 errors');
      expect(stale.tone, PrinterRowTone.amber);
    });

    test('shows Ready instead of OK when the printer is idle', () {
      final summary = resolvePrinterRowSummary(
        PrinterHealth(
          state: 'ready',
          snmpOk: verified.snmpOk,
          maintenance: verified.maintenance,
          errorHistory: const PrinterErrorHistory(available: true),
        ),
      );
      expect(summary.label, 'Ready');
      expect(summary.tone, PrinterRowTone.ok);
      final printing = resolvePrinterStatus(const PrinterHealth(state: 'printing'));
      expect(printing.label, 'Printing');
      expect(printing.kind, PrinterStatusKind.printing);
      expect(printing.fault, isFalse);
    });

    test('shows Out of paper ahead of a recorded error', () {
      final summary = resolvePrinterRowSummary(
        PrinterHealth(
          state: 'paper_out',
          snmpOk: verified.snmpOk,
          maintenance: verified.maintenance,
          errorHistory: const PrinterErrorHistory(
            available: true,
            entries: [PrinterErrorEntry(index: 1, description: 'Cannot Print ZC')],
          ),
        ),
      );
      expect(summary.label, 'Out of paper');
      expect(summary.tone, PrinterRowTone.alert);
    });

    test('keeps a fault amber when the sample is stale', () {
      final summary = resolvePrinterRowSummary(
        PrinterHealth(
          state: 'paper_out',
          snmpOk: false,
          maintenance: verified.maintenance,
          errorHistory: const PrinterErrorHistory(available: true),
        ),
      );
      expect(summary.label, 'Out of paper');
      expect(summary.tone, PrinterRowTone.amber);
    });

    test('leaves the summary unchanged when state is missing', () {
      final summary = resolvePrinterRowSummary(
        PrinterHealth(
          snmpOk: verified.snmpOk,
          maintenance: verified.maintenance,
          errorHistory: const PrinterErrorHistory(available: true),
        ),
      );
      expect(summary.label, 'OK');
      expect(resolvePrinterStatus(const PrinterHealth()).kind, PrinterStatusKind.unavailable);
      expect(resolvePrinterStatus(const PrinterHealth(state: 'unknown')).label, 'Unavailable');
    });
  });
}
