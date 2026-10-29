import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/charging/domain/charger_message.dart';

void main() {
  group('ChargerMessage.tryParse', () {
    test('parses plug, unplug, full, and timeout events', () {
      final plugged = ChargerMessage.tryParse(
        '{"charger":"plugged_in","relay_state":"on","volts":5.02,"current_ma":820,"power_w":4.12,"ts":10}',
      );
      expect(plugged, isNotNull);
      expect(plugged!.notice, ChargerNotice.pluggedIn);
      expect(plugged.relayState, 'on');
      expect(plugged.volts, closeTo(5.02, 0.001));
      expect(plugged.currentMa, 820);
      expect(plugged.powerW, closeTo(4.12, 0.001));

      expect(
        ChargerMessage.tryParse(
          '{"charger":"plugged_out","relay_state":"off","volts":0,"current_ma":0,"power_w":0,"ts":11}',
        )!.notice,
        ChargerNotice.pluggedOut,
      );
      expect(
        ChargerMessage.tryParse(
          '{"charger":"charge_complete","relay_state":"off","volts":4.9,"current_ma":40,"power_w":0.2,"ts":12}',
        )!.notice,
        ChargerNotice.chargeComplete,
      );
      expect(
        ChargerMessage.tryParse(
          '{"charger":"charge_timeout","relay_state":"off","volts":5,"current_ma":100,"power_w":0.5,"ts":13}',
        )!.notice,
        ChargerNotice.chargeTimeout,
      );
    });

    test('parses a charger snapshot', () {
      final status = ChargerMessage.tryParse(
        '{"charger":"status","ina226":true,"state":"waiting_for_phone","plugged":false,"last_result":"none","relay_state":"on","volts":0.1,"current_ma":0,"power_w":0.0,"ts":20}',
      );
      expect(status, isNotNull);
      expect(status!.notice, ChargerNotice.snapshot);
      expect(status.ina226, isTrue);
      expect(status.firmwareState, 'waiting_for_phone');
      expect(status.plugged, isFalse);
      expect(status.lastResult, 'none');
      expect(status.relayState, 'on');
    });

    test('parses sensor loss and recovery', () {
      expect(
        ChargerMessage.tryParse(
          '{"charger":"ina226_error","relay_state":"on","volts":5,"current_ma":0,"power_w":0,"ts":1}',
        )!.notice,
        ChargerNotice.ina226Error,
      );
      expect(
        ChargerMessage.tryParse(
          '{"charger":"ina226_ready","relay_state":"on","volts":5,"current_ma":0,"power_w":0,"ts":2}',
        )!.notice,
        ChargerNotice.ina226Ready,
      );
    });

    test('ignores debug, link reports, and the I2C scan', () {
      expect(
        ChargerMessage.tryParse(
          '{"charger":"debug","relay_state":"on","volts":1,"current_ma":2,"power_w":3,"ts":1}',
        ),
        isNull,
      );
      expect(
        ChargerMessage.tryParse(
          '{"charger":"ina226_connected","addr":"0x40","i2c_ack":true,"i2c_err":0,"init_ok":true,"ts":1}',
        ),
        isNull,
      );
      expect(
        ChargerMessage.tryParse(
          '{"charger":"ina226_not_connected","addr":"0x40","i2c_ack":false,"i2c_err":2,"init_ok":false,"ts":1}',
        ),
        isNull,
      );
      expect(
        ChargerMessage.tryParse('{"i2c_found":["0x40","0x57","0x5A"],"ts":1}'),
        isNull,
      );
      expect(
        ChargerMessage.tryParse('{"ok":true,"relay":1,"state":"on"}'),
        isNull,
      );
    });
  });

  group('ChargerMessage.ina226FromReadyLine', () {
    test('reads the boot flag and ignores other lines', () {
      expect(
        ChargerMessage.ina226FromReadyLine(
          '{"status":"ready","device":"SPPC_CONTROLLER","ina226":true,"relay1":false}',
        ),
        isTrue,
      );
      expect(
        ChargerMessage.ina226FromReadyLine('{"status":"ready","ina226":false}'),
        isFalse,
      );
      expect(
        ChargerMessage.ina226FromReadyLine(
          '{"status":"ready","device":"SPPC_CONTROLLER"}',
        ),
        isNull,
      );
      expect(
        ChargerMessage.ina226FromReadyLine(
          '{"ok":true,"relay":1,"state":"on"}',
        ),
        isNull,
      );
    });
  });
}
