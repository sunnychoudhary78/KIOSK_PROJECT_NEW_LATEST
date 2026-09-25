import 'package:flutter/material.dart';

/// Focus wrapper so visitor pads also accept a physical keyboard.
class KioskHardwareKeys extends StatelessWidget {
  const KioskHardwareKeys({
    super.key,
    required this.onKeyEvent,
    required this.child,
    this.autofocus = true,
  });

  final KeyEventResult Function(KeyEvent event) onKeyEvent;
  final Widget child;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: autofocus,
      onKeyEvent: (node, event) => onKeyEvent(event),
      child: child,
    );
  }
}
