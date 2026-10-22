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

    test('!snmpReachable after threshold is fatal when configured', () {
      const health = PrinterHealth(
        state: 'ready',
        online: true,
        snmpConfigured: true,
        snmpReachable: false,
        consecutiveFailures: 3,
      );
      expect(health.isFatal, isTrue);
    });

    test('toJson omits community and includes telemetry fields', () {
      final json = const PrinterHealth(
        state: 'ready',
        online: true,
        pageCounter: 42,
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
      expect(json['pageCounter'], 42);
      expect(json['hrPrinterStatus'], 3);
      expect(json['errorFlagsHex'], '00');
      expect(json['snmpReachable'], isTrue);
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
