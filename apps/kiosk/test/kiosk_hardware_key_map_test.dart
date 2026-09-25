import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/input/kiosk_hardware_key_map.dart';
import 'package:skp_kiosk/core/ui/kiosk_date_stepper.dart';

KeyDownEvent _down(
  LogicalKeyboardKey logical,
  PhysicalKeyboardKey physical, {
  String? character,
}) {
  return KeyDownEvent(
    physicalKey: physical,
    logicalKey: logical,
    timeStamp: Duration.zero,
    character: character,
  );
}

void main() {
  group('mapOtpHardwareKey', () {
    test('maps digits, backspace, clear, and enter', () {
      expect(
        mapOtpHardwareKey(
          _down(
            LogicalKeyboardKey.digit4,
            PhysicalKeyboardKey.digit4,
            character: '4',
          ),
        )?.action,
        OtpHardwareAction.digit,
      );
      expect(
        mapOtpHardwareKey(
          _down(
            LogicalKeyboardKey.digit4,
            PhysicalKeyboardKey.digit4,
            character: '4',
          ),
        )?.digit,
        '4',
      );
      expect(
        mapOtpHardwareKey(
          _down(LogicalKeyboardKey.backspace, PhysicalKeyboardKey.backspace),
        )?.action,
        OtpHardwareAction.backspace,
      );
      expect(
        mapOtpHardwareKey(
          _down(LogicalKeyboardKey.delete, PhysicalKeyboardKey.delete),
        )?.action,
        OtpHardwareAction.clear,
      );
      expect(
        mapOtpHardwareKey(
          _down(LogicalKeyboardKey.keyC, PhysicalKeyboardKey.keyC, character: 'c'),
        )?.action,
        OtpHardwareAction.clear,
      );
      expect(
        mapOtpHardwareKey(
          _down(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
        )?.action,
        OtpHardwareAction.submit,
      );
    });

    test('ignores key up', () {
      final event = KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.digit1,
        logicalKey: LogicalKeyboardKey.digit1,
        timeStamp: Duration.zero,
      );
      expect(mapOtpHardwareKey(event), isNull);
    });
  });

  group('mapAstrologyHardwareKey', () {
    test('maps letters, backspace, tab, and arrows', () {
      expect(
        mapAstrologyHardwareKey(
          _down(LogicalKeyboardKey.keyA, PhysicalKeyboardKey.keyA, character: 'A'),
        )?.character,
        'A',
      );
      expect(
        mapAstrologyHardwareKey(
          _down(LogicalKeyboardKey.backspace, PhysicalKeyboardKey.backspace),
        )?.action,
        AstrologyHardwareAction.backspace,
      );
      expect(
        mapAstrologyHardwareKey(
          _down(LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab),
        )?.action,
        AstrologyHardwareAction.tab,
      );
      expect(
        mapAstrologyHardwareKey(
          _down(LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab),
          shiftPressed: true,
        )?.action,
        AstrologyHardwareAction.shiftTab,
      );
      expect(
        mapAstrologyHardwareKey(
          _down(LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp),
        )?.action,
        AstrologyHardwareAction.arrowUp,
      );
      expect(
        mapAstrologyHardwareKey(
          _down(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
        )?.action,
        AstrologyHardwareAction.submit,
      );
    });
  });

  group('nextStepperColumn', () {
    test('wraps around', () {
      expect(nextStepperColumn(2, 3, 1), 0);
      expect(nextStepperColumn(0, 3, -1), 2);
    });
  });

  group('date and time stepping', () {
    test('steps day and wraps', () {
      final next = KioskDateStepper.stepColumn(
        DateTime(2020, 1, 31),
        column: 0,
        delta: 1,
      );
      expect(next.day, 1);
      expect(next.month, 1);
    });

    test('steps hour wrapping midnight', () {
      final next = KioskTimeStepper.stepColumn(
        const TimeOfDay(hour: 23, minute: 10),
        column: 0,
        delta: 1,
      );
      expect(next.hour, 0);
      expect(next.minute, 10);
    });
  });
}
