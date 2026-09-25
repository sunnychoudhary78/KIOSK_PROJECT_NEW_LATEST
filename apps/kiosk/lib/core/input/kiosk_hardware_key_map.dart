import 'package:flutter/services.dart';

enum OtpHardwareAction { digit, backspace, clear, submit }

class OtpHardwareCommand {
  const OtpHardwareCommand(this.action, {this.digit});

  final OtpHardwareAction action;
  final String? digit;
}

enum AstrologyHardwareAction {
  character,
  backspace,
  tab,
  shiftTab,
  arrowUp,
  arrowDown,
  arrowLeft,
  arrowRight,
  submit,
}

class AstrologyHardwareCommand {
  const AstrologyHardwareCommand(this.action, {this.character});

  final AstrologyHardwareAction action;
  final String? character;
}

bool isHardwareKeyPress(KeyEvent event) =>
    event is KeyDownEvent || event is KeyRepeatEvent;

OtpHardwareCommand? mapOtpHardwareKey(KeyEvent event) {
  if (!isHardwareKeyPress(event)) {
    return null;
  }
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.backspace) {
    return const OtpHardwareCommand(OtpHardwareAction.backspace);
  }
  if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.keyC) {
    return const OtpHardwareCommand(OtpHardwareAction.clear);
  }
  if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
    return const OtpHardwareCommand(OtpHardwareAction.submit);
  }
  final digit = _digitOf(event);
  if (digit != null) {
    return OtpHardwareCommand(OtpHardwareAction.digit, digit: digit);
  }
  return null;
}

AstrologyHardwareCommand? mapAstrologyHardwareKey(
  KeyEvent event, {
  bool shiftPressed = false,
}) {
  if (!isHardwareKeyPress(event)) {
    return null;
  }
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.tab) {
    return AstrologyHardwareCommand(
      shiftPressed ? AstrologyHardwareAction.shiftTab : AstrologyHardwareAction.tab,
    );
  }
  if (key == LogicalKeyboardKey.backspace) {
    return const AstrologyHardwareCommand(AstrologyHardwareAction.backspace);
  }
  if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
    return const AstrologyHardwareCommand(AstrologyHardwareAction.submit);
  }
  if (key == LogicalKeyboardKey.arrowUp) {
    return const AstrologyHardwareCommand(AstrologyHardwareAction.arrowUp);
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    return const AstrologyHardwareCommand(AstrologyHardwareAction.arrowDown);
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    return const AstrologyHardwareCommand(AstrologyHardwareAction.arrowLeft);
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    return const AstrologyHardwareCommand(AstrologyHardwareAction.arrowRight);
  }

  final character = _printableCharacter(event);
  if (character != null) {
    return AstrologyHardwareCommand(
      AstrologyHardwareAction.character,
      character: character,
    );
  }
  return null;
}

int nextStepperColumn(int column, int columnCount, int delta) {
  if (columnCount <= 0) {
    return 0;
  }
  return (column + delta) % columnCount;
}

String? _digitOf(KeyEvent event) {
  final label = event.character ?? event.logicalKey.keyLabel;
  if (label.length == 1 && label.compareTo('0') >= 0 && label.compareTo('9') <= 0) {
    return label;
  }
  final numpad = {
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };
  return numpad[event.logicalKey];
}

String? _printableCharacter(KeyEvent event) {
  final raw = event.character;
  if (raw == null || raw.isEmpty) {
    return null;
  }
  if (raw == '\n' || raw == '\r' || raw == '\t') {
    return null;
  }
  if (raw.length == 1 && raw.codeUnitAt(0) >= 32) {
    return raw;
  }
  return null;
}
