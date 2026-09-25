import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-flow flags that pause or stretch the visitor idle timer.
class KioskSessionHold {
  const KioskSessionHold({
    this.printing = false,
    this.awaitingConsent = false,
    this.waiting = false,
  });

  final bool printing;
  final bool awaitingConsent;
  final bool waiting;

  KioskSessionHold copyWith({
    bool? printing,
    bool? awaitingConsent,
    bool? waiting,
  }) {
    return KioskSessionHold(
      printing: printing ?? this.printing,
      awaitingConsent: awaitingConsent ?? this.awaitingConsent,
      waiting: waiting ?? this.waiting,
    );
  }
}

class KioskSessionHoldController extends Notifier<KioskSessionHold> {
  @override
  KioskSessionHold build() => const KioskSessionHold();

  void set({bool? printing, bool? awaitingConsent, bool? waiting}) {
    final next = state.copyWith(
      printing: printing,
      awaitingConsent: awaitingConsent,
      waiting: waiting,
    );
    if (next.printing == state.printing &&
        next.awaitingConsent == state.awaitingConsent &&
        next.waiting == state.waiting) {
      return;
    }
    state = next;
  }

  void clear() {
    if (state.printing || state.awaitingConsent || state.waiting) {
      state = const KioskSessionHold();
    }
  }
}

final kioskSessionHoldProvider =
    NotifierProvider<KioskSessionHoldController, KioskSessionHold>(
  KioskSessionHoldController.new,
);
