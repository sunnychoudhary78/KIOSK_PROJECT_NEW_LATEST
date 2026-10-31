import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';

void main() {
  group('BrotherErrorFlagDecode (RFC 2790 first octet)', () {
    test('0x40 → noPaper (lab-confirmed paper_out)', () {
      final flags = BrotherErrorFlagDecode.fromHex('40');
      expect(flags['noPaper'], isTrue);
      expect(flags['jammed'], isFalse);
      expect(flags['offlineBit'], isFalse);
    });

    test('0x42 → noPaper + offlineBit', () {
      final flags = BrotherErrorFlagDecode.fromHex('42');
      expect(flags['noPaper'], isTrue);
      expect(flags['offlineBit'], isTrue);
      expect(flags['jammed'], isFalse);
    });

    test('0x04 → jammed', () {
      final flags = BrotherErrorFlagDecode.fromHex('04');
      expect(flags['jammed'], isTrue);
      expect(flags['noPaper'], isFalse);
    });

    test('0x02 → offlineBit only', () {
      final flags = BrotherErrorFlagDecode.fromHex('02');
      expect(flags['offlineBit'], isTrue);
      expect(flags['noPaper'], isFalse);
      expect(flags['jammed'], isFalse);
    });

    test('00 → none', () {
      final flags = BrotherErrorFlagDecode.fromHex('00');
      expect(flags['noPaper'], isFalse);
      expect(flags['jammed'], isFalse);
      expect(flags['offlineBit'], isFalse);
    });
  });

  group('PrinterHealth', () {
    test('offlineBit alone is not fatal', () {
      const health = PrinterHealth(
        state: 'ready',
        online: true,
        offlineBit: true,
        snmpConfigured: true,
        snmpReachable: true,
      );
      expect(health.isFatal, isFalse);
    });

    test('noPaper / paper_out is fatal', () {
      expect(
        const PrinterHealth(state: 'paper_out', online: true, noPaper: true)
            .isFatal,
        isTrue,
      );
    });

    test('USB_PRINTER_NOT_FOUND names the USB cable', () {
      const health = PrinterHealth(
        state: 'offline',
        online: false,
        lastErrorCode: 'USB_PRINTER_NOT_FOUND',
        snmpConfigured: true,
        snmpReachable: true,
      );
      expect(health.userMessage, contains('USB printer was not found'));
    });

    test('an unreachable poll flag does not block a ready printer', () {
      const health = PrinterHealth(
        state: 'ready',
        online: true,
        snmpOk: false,
        snmpReachable: false,
        consecutiveFailures: 3,
      );
      expect(health.isFatal, isFalse);
      expect(health.isPhysicalFatal, isFalse);
    });

    test('offline names the USB cable', () {
      const health = PrinterHealth(
        state: 'offline',
        online: false,
        lastErrorCode: 'OFFLINE',
      );
      expect(health.userMessage, contains('USB cable'));
    });

    test('toJson omits community and includes telemetry fields', () {
      final json = const PrinterHealth(
        state: 'ready',
        online: true,
        snmpReachable: true,
        consecutiveFailures: 0,
        hrPrinterStatus: 3,
        hrPrinterStatusLabel: 'idle',
        errorFlagsHex: '00',
        noPaper: false,
        jammed: false,
        offlineBit: false,
        spoolerJobsQueued: 0,
        spoolerJobsPrinting: 0,
      ).toJson();

      expect(json.containsKey('community'), isFalse);
      expect(json.containsKey('snmpCommunity'), isFalse);
      expect(json.containsKey('pageCounter'), isFalse);
      expect(json['hrPrinterStatus'], 3);
      expect(json['errorFlagsHex'], '00');
      expect(json['snmpReachable'], isTrue);
      expect(json.containsKey('maintenance'), isFalse);
      expect(json.containsKey('errorHistory'), isFalse);
    });

    test('toJson includes verified maintenance and omits empty metrics', () {
      final json = const PrinterHealth(
        state: 'ready',
        online: true,
        maintenance: PrinterMaintenance(
          available: true,
          toner: PrinterMaintenanceToner(
            blackPercent: 90,
            cyanPercent: 100,
            magentaPercent: 100,
            yellowPercent: 100,
          ),
          pages: PrinterMaintenancePages(total: 64, color: 47, blackAndWhite: 17),
          parts: PrinterMaintenanceParts(
            beltRemainingPages: 49882,
            fuserRemainingPages: 49936,
          ),
        ),
      ).toJson();

      expect(json.containsKey('community'), isFalse);
      expect(json['maintenance'], {
        'available': true,
        'toner': {
          'blackPercent': 90,
          'cyanPercent': 100,
          'magentaPercent': 100,
          'yellowPercent': 100,
        },
        'pages': {'total': 64, 'color': 47, 'blackAndWhite': 17},
        'parts': {'beltRemainingPages': 49882, 'fuserRemainingPages': 49936},
      });
    });

    test('toJson keeps one error description and omits an empty history list', () {
      final json = const PrinterHealth(
        state: 'ready',
        online: true,
        errorHistory: PrinterErrorHistory(
          available: true,
          entries: [
            PrinterErrorHistoryEntry(index: 1, description: 'Cannot Print ZC'),
          ],
        ),
      ).toJson();
      expect(json.containsKey('community'), isFalse);
      expect(json['errorHistory'], {
        'available': true,
        'entries': [
          {'index': 1, 'description': 'Cannot Print ZC'},
        ],
      });

      final empty = const PrinterHealth(
        state: 'ready',
        online: true,
        errorHistory: PrinterErrorHistory(available: true),
      ).toJson();
      expect(empty['errorHistory'], {'available': true});
      expect((empty['errorHistory'] as Map).containsKey('entries'), isFalse);
    });

    test('fromJson keeps a zero toner and leaves a missing color empty', () {
      final health = PrinterHealth.fromJson({
        'state': 'ready',
        'online': true,
        'maintenance': {
          'available': true,
          'toner': {'blackPercent': 0},
        },
      });
      expect(health.maintenance?.available, isTrue);
      expect(health.maintenance?.toner?.blackPercent, 0);
      expect(health.maintenance?.toner?.cyanPercent, isNull);
      expect(health.maintenance?.toJson()['toner'], {'blackPercent': 0});
    });

    test('fromJson round-trips new fields', () {
      final health = PrinterHealth.fromJson({
        'state': 'printing',
        'online': true,
        'hrPrinterStatus': 4,
        'hrPrinterStatusLabel': 'printing',
        'errorFlagsHex': '40',
        'noPaper': true,
        'snmpReachable': true,
        'consecutiveFailures': 0,
        'spoolerJobsPrinting': 1,
      });
      expect(health.hrPrinterStatus, 4);
      expect(health.hrPrinterStatusLabel, 'printing');
      expect(health.errorFlagsHex, '40');
      expect(health.noPaper, isTrue);
      expect(health.spoolerJobsPrinting, 1);
      expect(health.isBusy, isTrue);
    });
  });
}
