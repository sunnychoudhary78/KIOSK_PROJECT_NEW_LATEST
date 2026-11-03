import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';

/// Service-screen back control.
///
/// When [endSessionOnPop] is true (top-level services), system/programmatic
/// pops while in-service wipe visitor state and return to the catalog.
/// When false (nested feature routes), one-level [Navigator.pop] is allowed
/// without ending the visitor session.
class VisitorSessionPopScope extends ConsumerWidget {
  const VisitorSessionPopScope({
    super.key,
    required this.child,
    this.endSessionOnPop = true,
  });

  final Widget child;

  /// If true, blocked pops end the visitor session. If false, nested pops work.
  final bool endSessionOnPop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!endSessionOnPop) {
      // No PopScope: allow a normal one-level Navigator.pop to the parent route.
      return child;
    }

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
