import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-flow flags that pause or stretch the visitor idle timer.
class KioskSessionHold {
  const KioskSessionHold({
    this.printing = false,
    this.awaitingConsent = false,
  });

  final bool printing;
  final bool awaitingConsent;

  KioskSessionHold copyWith({
    bool? printing,
    bool? awaitingConsent,
  }) {
    return KioskSessionHold(
      printing: printing ?? this.printing,
      awaitingConsent: awaitingConsent ?? this.awaitingConsent,
    );
  }
}

class KioskSessionHoldController extends Notifier<KioskSessionHold> {
  @override
  KioskSessionHold build() => const KioskSessionHold();

  void set({bool? printing, bool? awaitingConsent}) {
    final next = state.copyWith(
      printing: printing,
      awaitingConsent: awaitingConsent,
    );
    if (next.printing == state.printing &&
        next.awaitingConsent == state.awaitingConsent) {
      return;
    }
    state = next;
  }

  void clear() {
    if (state.printing || state.awaitingConsent) {
      state = const KioskSessionHold();
    }
  }
}

final kioskSessionHoldProvider =
    NotifierProvider<KioskSessionHoldController, KioskSessionHold>(
  KioskSessionHoldController.new,
);
