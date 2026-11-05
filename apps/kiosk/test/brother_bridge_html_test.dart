import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/services/printer/brother_bridge_html.dart';
import 'package:skp_kiosk/services/printer/usb_snapshot.dart';

void main() {
  late String monitorHtml;
  late String maintenanceHtml;

  setUpAll(() {
    final root = Directory.current.path.endsWith('kiosk')
        ? Directory.current.path
        : '${Directory.current.path}/apps/kiosk';
    monitorHtml = File('$root/test/fixtures/brother_bridge/monitor.html')
        .readAsStringSync();
    maintenanceHtml = File(
      '$root/test/fixtures/brother_bridge/maintenance_information.html',
    ).readAsStringSync();
  });

  test('parses monitor Sleep as legacy sleep status code', () {
    final monitor = parseBrotherMonitorHtml(monitorHtml);
    expect(monitor.statusMessage, 'Sleep');
    expect(monitor.statusType, 'Ready');
    expect(monitor.statusCode, usbStatusSleep);
  });

  test('parses maintenance ink pages model serial and errors', () {
    final maintenance = parseBrotherMaintenanceHtml(maintenanceHtml);
    expect(maintenance.pagesTotal, 5);
    expect(maintenance.pagesColor, 5);
    expect(maintenance.pagesBlackAndWhite, 0);
    expect(maintenance.tonerBlack, 99);
    expect(maintenance.tonerCyan, 99);
    expect(maintenance.tonerMagenta, 99);
    expect(maintenance.tonerYellow, 99);
    expect(maintenance.model, contains('DCP-T830DW'));
    expect(maintenance.serialNumber, isNotEmpty);
    expect(maintenance.firmwareMain, '1.14');
    expect(maintenance.errorHistory, isNotEmpty);
    expect(maintenance.errorHistory.first.description, contains('Wrong Tray'));
    expect(maintenance.errorHistory.length, greaterThanOrEqualTo(2));
  });

  test('parses first Total duplex and refill; ignores Copy/Scan nested counters', () {
    final maintenance = parseBrotherMaintenanceHtml(maintenanceHtml);
    expect(maintenance.pagesDuplexTotal, 1);
    expect(maintenance.pagesDuplexColor, 1);
    expect(maintenance.pagesDuplexBlackAndWhite, 0);
    expect(maintenance.refillBlack, 0);
    expect(maintenance.refillCyan, 0);
    expect(maintenance.refillMagenta, 0);
    expect(maintenance.refillYellow, 0);
    final snap = snapshotFromBrotherBridgeHtml(
      monitorHtml: monitorHtml,
      maintenanceHtml: maintenanceHtml,
      full: false,
    );
    expect(snap.pagesDuplexTotal, 1);
    expect(snap.refillCyan, 0);
  });

  test('full snapshot includes error history; fast omits it', () {
    final full = snapshotFromBrotherBridgeHtml(
      monitorHtml: monitorHtml,
      maintenanceHtml: maintenanceHtml,
      full: true,
    );
    expect(full.ok, isTrue);
    expect(full.pagesTotal, 5);
    expect(full.tonerBlack, 99);
    expect(full.statusCode, usbStatusSleep);
    expect(full.errorHistory, isNotNull);
    expect(full.errorHistory, isNotEmpty);

    final fast = snapshotFromBrotherBridgeHtml(
      monitorHtml: monitorHtml,
      maintenanceHtml: maintenanceHtml,
      full: false,
    );
    expect(fast.errorHistory, isNull);
    expect(fast.pagesTotal, 5);
  });

  test('maps paper-out style messages to legacy paper-out code', () {
    expect(statusCodeFromBrotherMessage('Out of Paper'), usbStatusPaperOut);
    expect(
      statusCodeFromBrotherMessage('Paper Tray 1 not detected'),
      usbStatusPaperOut,
    );
    expect(statusCodeFromBrotherMessage('Printing'), usbStatusPrinting);
    expect(statusCodeFromBrotherMessage('Ready'), usbStatusReady);
  });
}
