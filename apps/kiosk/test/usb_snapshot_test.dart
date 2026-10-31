import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';
import 'package:skp_kiosk/services/printer/printer_monitor.dart';
import 'package:skp_kiosk/services/printer/printer_native.dart';
import 'package:skp_kiosk/services/printer/usb_page_watch.dart';
import 'package:skp_kiosk/services/printer/usb_snapshot.dart';

void main() {
  test('decode maps page and next-care ids and ignores an unknown id', () {
    final decoded = decodeBrotherUsbRecords([
      0x00, 0x01, 0x04, 0x00, 0x00, 0x00, 176,
      0x02, 0x01, 0x04, 0x00, 0x00, 0x00, 159,
      0x01, 0x01, 0x04, 0x00, 0x00, 0x00, 17,
      0x63, 0x01, 0x04, 0x00, 0x00, 0x00, 5,
      0x88, 0x01, 0x04, 0x00, 0x00, 0xC2, 0x7E,
      0x73, 0x01, 0x04, 0x00, 0x00, 0xC2, 0xA0,
      0xFF,
    ]);

    expect(decoded.pagesTotal, 176);
    expect(decoded.pagesColor, 159);
    expect(decoded.pagesBlackAndWhite, 17);
    expect(decoded.beltRemainingPages, 49790);
    expect(decoded.fuserRemainingPages, 49824);
    expect(decoded.ignoredIds, [0x63]);
  });

  test('compare line records the USB page delta without touching heartbeat JSON', () {
    const health = PrinterHealth(
      state: 'ready',
      online: true,
      snmpReachable: true,
      snmpConfigured: true,
    );
    const snapshot = UsbSnapshot(
      ok: true,
      connected: true,
      statusCode: 10001,
      statusMessage: 'Ready',
      tonerBlack: 80,
      pagesTotal: 176,
      beltRemainingPages: 49790,
    );

    final line = formatUsbCompareLine(
      previousUsbPages: 172,
      snapshot: snapshot,
    );

    expect(
      line,
      'PRINTER usb-compare pagesTotalUsb=176 '
      'deltaUsb=4 statusCode=10001 statusMessage=Ready tonerBlack=80 belt=49790',
    );
    expect(line.contains('pageSnmp'), isFalse);
    expect(health.toJson().containsKey('pagesTotal'), isFalse);
    expect(health.toJson().containsKey('usbError'), isFalse);
    expect(health.toJson().containsKey('statusCode'), isFalse);
  });

  test('a failed USB read leaves SNMP health and reachability unchanged', () {
    const health = PrinterHealth(
      state: 'ready',
      online: true,
      snmpReachable: true,
      snmpConfigured: true,
    );
    final failed = UsbSnapshot.failed('helper_missing');
    final after = healthAfterUsbRead(health, failed);

    expect(after.toJson(), health.toJson());
    expect(after.snmpReachable, isTrue);
    expect(after.snmpReachable, health.snmpReachable);
    expect(
      formatUsbCompareLine(
        previousUsbPages: null,
        snapshot: failed,
      ),
      'PRINTER usb-compare usbError=helper_missing',
    );
  });

  test('known USB status codes classify and Sleep stays online', () {
    expect(usbStatusKind(40000), 'sleep');
    expect(usbStatusKind(10001), 'ready');
    expect(usbStatusKind(10003), 'wait');
    expect(usbStatusKind(10023), 'printing');

    const health = PrinterHealth(state: 'ready', online: true);
    final after = healthAfterUsbStatus(health, 40000);

    expect(after.online, isTrue);
    expect(after.state, 'ready');
    expect(after.toJson(), health.toJson());
    expect(
      formatUsbStatusLine(code: 40000, message: 'Sleep'),
      'PRINTER usb-status code=40000 message=Sleep kind=sleep',
    );
  });

  test('an unmapped USB status does not set or clear paper-out', () {
    expect(usbStatusKind(50000), 'unmapped');
    expect(usbStatusKind(null), 'unmapped');

    const ready = PrinterHealth(state: 'ready', online: true);
    final stillReady = healthAfterUsbStatus(ready, 50000);
    expect(stillReady.noPaper, isFalse);
    expect(stillReady.state, 'ready');
    expect(stillReady.toJson().containsKey('statusCode'), isFalse);

    const paperOut = PrinterHealth(
      state: 'paper_out',
      online: true,
      noPaper: true,
    );
    final stillOut = healthAfterUsbStatus(paperOut, 10001);
    expect(stillOut.noPaper, isTrue);
    expect(stillOut.state, 'paper_out');
    expect(
      formatUsbStatusLine(code: 50000, message: 'Load paper'),
      'PRINTER usb-status code=50000 message=Load paper kind=unmapped',
    );
  });

  test('a failed USB snapshot leaves the last status in place', () {
    final watch = UsbPageWatch();
    watch.record(
      const UsbSnapshot(
        ok: true,
        connected: true,
        pagesTotal: 203,
        statusCode: 40000,
        statusMessage: 'Sleep',
      ),
    );
    watch.record(UsbSnapshot.failed('busy'));

    expect(watch.latestPages, 203);
    expect(watch.statusCode, 40000);
    expect(watch.statusMessage, 'Sleep');
    expect(watch.freshPages(), 203);
    expect(watch.paperOutLatched, isFalse);
  });

  test('41236 latches paper-out until Ready, including over an SNMP jam', () {
    const ready = PrinterHealth(state: 'ready', online: true);
    final paper = healthAfterUsbStatus(ready, usbStatusPaperOut);

    expect(usbStatusKind(usbStatusPaperOut), 'paper_out');
    expect(paper.noPaper, isTrue);
    expect(paper.state, 'paper_out');
    expect(paper.online, isTrue);
    expect(paper.lastErrorCode, 'PAPER_OUT');
    expect(paper.toJson().containsKey('statusCode'), isFalse);

    const jam = PrinterHealth(state: 'jam', online: true, jammed: true);
    final paperOverJam = healthAfterUsbStatus(jam, usbStatusPaperOut);
    expect(paperOverJam.state, 'paper_out');
    expect(paperOverJam.jammed, isFalse);
    expect(paperOverJam.noPaper, isTrue);

    const snmpPaper = PrinterHealth(
      state: 'paper_out',
      online: true,
      noPaper: true,
    );
    final stillSnmp = healthAfterUsbStatus(snmpPaper, usbStatusReady);
    expect(stillSnmp.noPaper, isTrue);
    expect(stillSnmp.state, 'paper_out');

    final watch = UsbPageWatch();
    watch.record(
      const UsbSnapshot(
        ok: true,
        connected: true,
        pagesTotal: 207,
        statusCode: usbStatusPaperOut,
        statusMessage: 'No Paper T1',
      ),
    );
    expect(watch.paperOutLatched, isTrue);
    watch.record(
      const UsbSnapshot(
        ok: true,
        connected: true,
        pagesTotal: 207,
        statusCode: usbStatusPrinting,
        statusMessage: 'Printing',
      ),
    );
    expect(watch.paperOutLatched, isTrue);
    watch.record(
      const UsbSnapshot(
        ok: true,
        connected: true,
        pagesTotal: 207,
        statusCode: usbStatusWait,
        statusMessage: 'Please Wait',
      ),
    );
    expect(watch.paperOutLatched, isTrue);
    watch.record(UsbSnapshot.failed('busy'));
    expect(watch.paperOutLatched, isTrue);
    expect(watch.statusCode, usbStatusWait);
    watch.record(
      const UsbSnapshot(
        ok: true,
        connected: true,
        pagesTotal: 207,
        statusCode: usbStatusReady,
        statusMessage: 'Ready',
      ),
    );
    expect(watch.paperOutLatched, isFalse);
  });

  test('maintenance toner ids 129-132 are percents and out-of-range values are omitted', () {
    final decoded = decodeBrotherUsbRecords([
      0x81, 0x01, 0x04, 0x00, 0x00, 0x00, 80,
      0x82, 0x01, 0x04, 0x00, 0x00, 0x00, 90,
      0x83, 0x01, 0x04, 0x00, 0x00, 0x00, 90,
      0x84, 0x01, 0x04, 0x00, 0x00, 0x00, 0,
      0x81, 0x01, 0x04, 0x00, 0x00, 0x27, 0x10,
      0x63, 0x01, 0x04, 0x00, 0x00, 0x00, 5,
    ]);

    expect(decoded.tonerBlack, 80);
    expect(decoded.tonerCyan, 90);
    expect(decoded.tonerMagenta, 90);
    expect(decoded.tonerYellow, 0);
    expect(decoded.ignoredIds, [0x63]);

    final overRange = decodeBrotherUsbRecords([
      0x82, 0x01, 0x04, 0x00, 0x00, 0x27, 0x10,
    ]);
    expect(overRange.tonerCyan, isNull);
    expect(overRange.ignoredIds, isEmpty);
  });

  test('a fast snapshot and a busy read keep latched toner on the compare line', () {
    final watch = UsbPageWatch();
    watch.record(
      const UsbSnapshot(
        ok: true,
        connected: true,
        tonerBlack: 80,
        tonerCyan: 90,
        tonerMagenta: 90,
        tonerYellow: 0,
      ),
    );
    watch.record(
      const UsbSnapshot(
        ok: true,
        connected: true,
        pagesTotal: 216,
        statusCode: usbStatusPrinting,
        statusMessage: 'Printing',
      ),
    );
    expect(watch.tonerBlack, 80);
    expect(watch.tonerCyan, 90);
    expect(watch.tonerYellow, 0);
    watch.record(UsbSnapshot.failed('busy'));
    expect(watch.tonerCyan, 90);
    expect(watch.tonerYellow, 0);

    final line = formatUsbCompareLine(
      previousUsbPages: 216,
      snapshot: const UsbSnapshot(
        ok: true,
        connected: true,
        pagesTotal: 216,
        statusCode: usbStatusPrinting,
      ),
      tonerBlack: watch.tonerBlack,
      tonerCyan: watch.tonerCyan,
      tonerMagenta: watch.tonerMagenta,
      tonerYellow: watch.tonerYellow,
    );
    expect(line, contains('tonerCyan=90'));
    expect(line, contains('tonerYellow=0'));
  });

  test('getHealth uses USB toner only and leaves an unread SNMP color blank', () async {
    final watch = UsbPageWatch();
    watch.record(
      const UsbSnapshot(
        ok: true,
        connected: true,
        tonerBlack: 5,
        tonerMagenta: 90,
        tonerYellow: 90,
      ),
    );
    final native = FakePrinterNative(
      health: const PrinterHealth(
        state: 'ready',
        online: true,
        supplies: [
          PrinterSupplyHealth(name: 'Black Toner', color: 'black', levelPercent: 80),
        ],
        trays: [PrinterTrayHealth(name: 'Tray 1', levelPercent: 40)],
        errorHistory: PrinterErrorHistory(
          available: true,
          entries: [PrinterErrorHistoryEntry(index: 1, description: 'snmp')],
        ),
        maintenance: PrinterMaintenance(
          available: true,
          toner: PrinterMaintenanceToner(
            blackPercent: 80,
            cyanPercent: 40,
          ),
          pages: PrinterMaintenancePages(total: 216),
          parts: PrinterMaintenanceParts(beltRemainingPages: 49744),
        ),
      ),
    );
    final monitor = PrinterMonitor(
      native: native,
      config: const AppConfig(
        apiBaseUrl: 'http://localhost',
        environment: 'test',
      ),
      usbPageWatch: watch,
    );

    final health = await monitor.getHealth();

    expect(health.state, 'ready');
    expect(health.lowToner, isFalse);
    expect(health.noToner, isFalse);
    expect(health.maintenance?.toner?.blackPercent, 5);
    expect(health.maintenance?.toner?.cyanPercent, isNull);
    expect(health.maintenance?.toner?.magentaPercent, 90);
    expect(health.maintenance?.toner?.yellowPercent, 90);
    expect(health.maintenance?.pages?.total, isNull);
    expect(health.maintenance?.parts?.beltRemainingPages, isNull);
    expect(health.supplies, isEmpty);
    expect(health.trays, isEmpty);
    final json = health.toJson();
    expect(json.containsKey('tonerBlack'), isFalse);
    expect(json.containsKey('tonerCyan'), isFalse);
    expect(json.containsKey('errorHistory'), isFalse);
    expect(json.containsKey('pageCounter'), isFalse);
    expect(json['maintenance']['toner'].containsKey('cyanPercent'), isFalse);
  });

  test('USB ready, sleep, wait, and printing set state and paper-out still wins', () async {
    Future<PrinterHealth> overlay({
      required PrinterHealth health,
      required int code,
      String message = '',
    }) async {
      final watch = UsbPageWatch();
      watch.record(
        UsbSnapshot(
          ok: true,
          connected: true,
          statusCode: code,
          statusMessage: message,
        ),
      );
      final monitor = PrinterMonitor(
        native: FakePrinterNative(health: health),
        config: const AppConfig(apiBaseUrl: 'http://localhost', environment: 'test'),
        usbPageWatch: watch,
      );
      return monitor.getHealth();
    }

    final printing = await overlay(
      health: const PrinterHealth(state: 'ready', online: true),
      code: usbStatusPrinting,
    );
    expect(printing.state, 'printing');
    expect(printing.online, isTrue);

    final waiting = await overlay(
      health: const PrinterHealth(state: 'ready', online: true),
      code: usbStatusWait,
    );
    expect(waiting.state, 'printing');

    final ready = await overlay(
      health: const PrinterHealth(state: 'printing', online: true),
      code: usbStatusReady,
    );
    expect(ready.state, 'ready');
    expect(ready.online, isTrue);

    final sleep = await overlay(
      health: const PrinterHealth(state: 'printing', online: true),
      code: usbStatusSleep,
    );
    expect(sleep.state, 'ready');
    expect(sleep.online, isTrue);

    final paper = await overlay(
      health: const PrinterHealth(state: 'ready', online: true),
      code: usbStatusPaperOut,
    );
    expect(paper.state, 'paper_out');
    expect(paper.noPaper, isTrue);

    final jam = await overlay(
      health: const PrinterHealth(state: 'jam', online: true, jammed: true),
      code: usbStatusReady,
    );
    expect(jam.state, 'ready');
    expect(jam.jammed, isFalse);
    expect(jam.noPaper, isFalse);

    final unmapped = await overlay(
      health: const PrinterHealth(state: 'printing', online: true),
      code: 0,
    );
    expect(unmapped.state, 'printing');
  });

  test('fast and busy reads keep latched pages and parts and omit an unread fuser', () async {
    final watch = UsbPageWatch();
    watch.record(
      const UsbSnapshot(
        ok: true,
        connected: true,
        pagesTotal: 216,
        pagesColor: 20,
        pagesBlackAndWhite: 196,
        beltRemainingPages: 49743,
        tonerBlack: 80,
      ),
    );
    watch.record(
      const UsbSnapshot(
        ok: true,
        connected: true,
        pagesTotal: 216,
        statusCode: usbStatusPrinting,
      ),
    );
    expect(watch.pagesColor, 20);
    expect(watch.beltRemainingPages, 49743);
    watch.record(UsbSnapshot.failed('busy'));
    expect(watch.pagesBlackAndWhite, 196);
    expect(watch.fuserRemainingPages, isNull);

    final monitor = PrinterMonitor(
      native: FakePrinterNative(
        health: const PrinterHealth(
          state: 'ready',
          online: true,
          maintenance: PrinterMaintenance(
            available: true,
            parts: PrinterMaintenanceParts(fuserRemainingPages: 49824),
          ),
        ),
      ),
      config: const AppConfig(apiBaseUrl: 'http://localhost', environment: 'test'),
      usbPageWatch: watch,
    );
    final health = await monitor.getHealth();
    expect(health.maintenance?.pages?.total, 216);
    expect(health.maintenance?.pages?.color, 20);
    expect(health.maintenance?.pages?.blackAndWhite, 196);
    expect(health.maintenance?.parts?.beltRemainingPages, 49743);
    expect(health.maintenance?.parts?.fuserRemainingPages, isNull);
    expect(health.toJson().containsKey('beltRemainingPages'), isFalse);
    expect(health.toJson().containsKey('pagesColor'), isFalse);
  });

  test('full USB error history replaces SNMP history and a fast read keeps it', () async {
    final beforeWatch = UsbPageWatch();
    beforeWatch.record(
      const UsbSnapshot(ok: true, connected: true, statusCode: usbStatusReady),
    );
    final before = await PrinterMonitor(
      native: FakePrinterNative(
        health: const PrinterHealth(
          state: 'ready',
          online: true,
          errorHistory: PrinterErrorHistory(
            available: true,
            entries: [PrinterErrorHistoryEntry(index: 1, description: 'snmp')],
          ),
        ),
      ),
      config: const AppConfig(apiBaseUrl: 'http://localhost', environment: 'test'),
      usbPageWatch: beforeWatch,
    ).getHealth();
    expect(before.toJson().containsKey('errorHistory'), isFalse);
    final descriptions = [
      for (var i = 0; i < 11; i++) {'index': i, 'description': 'error $i', 'pageCount': i},
    ];
    final full = UsbSnapshot.fromJson({
      'ok': true,
      'connected': true,
      'errorHistory': descriptions,
    });
    expect(full.errorHistory, isNotNull);
    expect(full.errorHistory, hasLength(10));
    expect(full.errorHistory!.first.index, 1);
    expect(full.errorHistory!.first.description, 'error 0');
    expect(full.errorHistory!.last.description, 'error 9');

    final watch = UsbPageWatch();
    watch.record(full);
    watch.record(
      const UsbSnapshot(ok: true, connected: true, pagesTotal: 216, statusCode: usbStatusReady),
    );
    expect(watch.errorHistory, hasLength(10));

    final cleared = UsbSnapshot.fromJson({
      'ok': true,
      'connected': true,
      'errorHistory': <Map<String, dynamic>>[],
    });
    watch.record(cleared);
    expect(watch.errorHistory, isEmpty);

    final monitor = PrinterMonitor(
      native: FakePrinterNative(
        health: const PrinterHealth(
          state: 'ready',
          online: true,
          errorHistory: PrinterErrorHistory(
            available: true,
            entries: [PrinterErrorHistoryEntry(index: 1, description: 'snmp')],
          ),
        ),
      ),
      config: const AppConfig(apiBaseUrl: 'http://localhost', environment: 'test'),
      usbPageWatch: watch,
    );
    final health = await monitor.getHealth();
    expect(health.errorHistory?.available, isTrue);
    expect(health.errorHistory?.entries, isEmpty);
    expect(health.toJson()['errorHistory'], {'available': true});
  });

  test('a successful USB read overrides a failed SNMP poll and a later failure keeps toner', () async {
    final watch = UsbPageWatch();
    watch.record(
      const UsbSnapshot(ok: true, connected: true, tonerBlack: 80, statusCode: usbStatusReady),
    );
    final native = FakePrinterNative(
      health: const PrinterHealth(
        state: 'ready',
        online: true,
        snmpOk: false,
        snmpReachable: false,
      ),
    );
    final monitor = PrinterMonitor(
      native: native,
      config: const AppConfig(apiBaseUrl: 'http://localhost', environment: 'test'),
      usbPageWatch: watch,
    );

    final current = await monitor.getHealth();
    expect(current.snmpOk, isTrue);
    expect(current.snmpReachable, isTrue);
    expect(current.maintenance?.toner?.blackPercent, 80);
    expect(current.toJson()['lastSuccessAt'], isNotNull);

    watch.record(UsbSnapshot.failed('usb_timeout'));
    final stale = await monitor.getHealth();
    expect(stale.snmpOk, isFalse);
    expect(stale.maintenance?.toner?.blackPercent, 80);
  });
}
