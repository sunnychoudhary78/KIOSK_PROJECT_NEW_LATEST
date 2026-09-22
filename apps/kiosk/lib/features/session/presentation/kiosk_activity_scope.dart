import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';

/// Reports pointer and key input to the visitor session watchdog.
class KioskActivityScope extends ConsumerWidget {
  const KioskActivityScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void note() =>
        ref.read(kioskSessionControllerProvider.notifier).noteActivity();

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          note();
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => note(),
        child: child,
      ),
    );
  }
}
