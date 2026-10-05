import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/hardware/serial/relay_command.dart';

void main() {
  group('RelayCommands', () {
    test('builds charging on/off JSON for relay 1', () {
      expect(RelayCommands.chargingRelayNumber, 1);
      expect(RelayCommands.chargingOn(), '{"relay":1,"state":"on"}');
      expect(RelayCommands.chargingOff(), '{"relay":1,"state":"off"}');
    });

    test('builds arbitrary relay state', () {
      expect(
        RelayCommands.setState(relay: 2, on: false),
        '{"relay":2,"state":"off"}',
      );
    });
  });

  group('RelayResponse.tryParse', () {
    test('parses success reply', () {
      final result = RelayResponse.tryParse(
        '{"ok":true,"relay":1,"state":"on"}',
      );
      expect(result, isNotNull);
      expect(result!.ok, isTrue);
      expect(result.relay, 1);
      expect(result.isOn, isTrue);
    });

    test('parses error reply', () {
      final result = RelayResponse.tryParse(
        '{"ok":false,"relay":1,"error":"invalid_state"}',
      );
      expect(result!.ok, isFalse);
      expect(result.error, 'invalid_state');
    });

    test('ignores sensor status lines', () {
      expect(
        RelayResponse.tryParse('{"status":"ready","max30102":true}'),
        isNull,
      );
      expect(
        RelayResponse.tryParse(
          '{"status":"complete","bpm":72,"spo2":98,"object_f":null}',
        ),
        isNull,
      );
    });

    test('confirms charging only when ok and gpio state match', () {
      final on = RelayResponse.tryParse(
        '{"ok":true,"relay":1,"state":"on"}',
      )!;
      expect(on.confirmsCharging(on: true), isTrue);
      expect(on.confirmsCharging(on: false), isFalse);

      final readbackOff = RelayResponse.tryParse(
        '{"ok":true,"relay":1,"state":"off"}',
      )!;
      expect(readbackOff.confirmsCharging(on: true), isFalse);
      expect(readbackOff.confirmsCharging(on: false), isTrue);

      final nack = RelayResponse.tryParse(
        '{"ok":false,"relay":1,"error":"invalid_state"}',
      )!;
      expect(nack.confirmsCharging(on: true), isFalse);
      expect(nack.confirmsCharging(on: false), isFalse);

      final otherRelay = RelayResponse.tryParse(
        '{"ok":true,"relay":2,"state":"on"}',
      )!;
      expect(otherRelay.confirmsCharging(on: true), isFalse);
    });
  });

  group('RelayResponse.isControllerReadyLine', () {
    test('matches the ESP32 boot ready line only', () {
      expect(
        RelayResponse.isControllerReadyLine(
          '{"status":"ready","device":"SPPC_CONTROLLER","relay1":false}',
        ),
        isTrue,
      );
      expect(
        RelayResponse.isControllerReadyLine('{"status":"recording"}'),
        isFalse,
      );
      expect(
        RelayResponse.isControllerReadyLine('{"ok":true,"relay":1,"state":"on"}'),
        isFalse,
      );
    });
  });
}
