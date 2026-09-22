import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';

/// Service-screen back control: wipe visitor state, then return to the catalog.
class VisitorSessionPopScope extends ConsumerWidget {
  const VisitorSessionPopScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(
      kioskSessionControllerProvider.select((state) => state.phase),
    );
    final allowPop = phase == KioskSessionPhase.resetting ||
        phase == KioskSessionPhase.catalog;
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await ref
            .read(kioskSessionControllerProvider.notifier)
            .endVisitorSession(attract: false);
      },
      child: child,
    );
  }
}
