import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_hold.dart';
import 'package:skp_kiosk/features/session/application/visitor_session_reset.dart';
import 'package:skp_kiosk/features/session/domain/kiosk_session_policy.dart';

enum KioskSessionPhase { catalog, inService, warning, resetting }

class KioskSessionState {
  const KioskSessionState({
    this.phase = KioskSessionPhase.catalog,
    this.onHome = true,
    this.warningRemaining = Duration.zero,
  });

  final KioskSessionPhase phase;
  final bool onHome;
  final Duration warningRemaining;

  KioskSessionState copyWith({
    KioskSessionPhase? phase,
    bool? onHome,
    Duration? warningRemaining,
  }) {
    return KioskSessionState(
      phase: phase ?? this.phase,
      onHome: onHome ?? this.onHome,
      warningRemaining: warningRemaining ?? this.warningRemaining,
    );
  }
}

final kioskSessionPolicyProvider = Provider<KioskSessionPolicy>((ref) {
  return const KioskSessionPolicy();
});

final kioskSessionControllerProvider =
    NotifierProvider<KioskSessionController, KioskSessionState>(
  KioskSessionController.new,
);

class KioskSessionController extends Notifier<KioskSessionState> {
  Timer? _idleTimer;
  Timer? _warningTick;

  @override
  KioskSessionState build() {
    ref.onDispose(_cancelTimers);
    ref.listen(deviceAuthProvider, (previous, next) {
      if (previous?.isAuthenticated == true && !next.isAuthenticated) {
        _cancelTimers();
        if (!state.onHome && state.phase != KioskSessionPhase.resetting) {
          unawaited(endVisitorSession(attract: false));
          return;
        }
        if (state.phase != KioskSessionPhase.catalog) {
          state = state.copyWith(
            phase: KioskSessionPhase.catalog,
            warningRemaining: Duration.zero,
          );
        }
        return;
      }
      if (!next.isAuthenticated) {
        _cancelTimers();
        if (state.phase != KioskSessionPhase.catalog) {
          state = state.copyWith(
            phase: KioskSessionPhase.catalog,
            warningRemaining: Duration.zero,
          );
        }
      }
    });
    ref.listen(kioskSessionHoldProvider, (previous, next) {
      if (state.phase != KioskSessionPhase.inService) {
        return;
      }
      if (next.printing || next.waiting) {
        _cancelTimers();
        return;
      }
      _armIdleTimer();
    });
    return const KioskSessionState();
  }

  KioskSessionPolicy get _policy => ref.read(kioskSessionPolicyProvider);

  void setOnHome(bool onHome) {
    if (state.phase == KioskSessionPhase.resetting) {
      return;
    }
    if (onHome == state.onHome &&
        (onHome
            ? state.phase == KioskSessionPhase.catalog
            : state.phase == KioskSessionPhase.inService ||
                state.phase == KioskSessionPhase.warning)) {
      if (onHome) {
        _cancelTimers();
      }
      return;
    }

    if (onHome) {
      _cancelTimers();
      ref.read(kioskSessionHoldProvider.notifier).clear();
      state = state.copyWith(
        phase: KioskSessionPhase.catalog,
        onHome: true,
        warningRemaining: Duration.zero,
      );
      return;
    }

    final auth = ref.read(deviceAuthProvider);
    if (!auth.isAuthenticated) {
      return;
    }
    state = state.copyWith(
      phase: KioskSessionPhase.inService,
      onHome: false,
      warningRemaining: Duration.zero,
    );
    _armIdleTimer();
  }

  /// Any visitor input. No-op on the catalog / attract screen.
  void noteActivity() {
    if (!ref.read(deviceAuthProvider).isAuthenticated) {
      return;
    }
    if (state.onHome ||
        state.phase == KioskSessionPhase.catalog ||
        state.phase == KioskSessionPhase.resetting) {
      return;
    }
    if (state.phase == KioskSessionPhase.warning) {
      state = state.copyWith(
        phase: KioskSessionPhase.inService,
        warningRemaining: Duration.zero,
      );
    }
    _armIdleTimer();
  }

  Future<void> endVisitorSession({required bool attract}) async {
    if (state.phase == KioskSessionPhase.resetting) {
      return;
    }
    _cancelTimers();
    ref.read(kioskSessionHoldProvider.notifier).clear();
    state = state.copyWith(
      phase: KioskSessionPhase.resetting,
      warningRemaining: Duration.zero,
    );

    try {
      await ref.read(visitorSessionResetProvider)(attract: attract);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(
          phase: KioskSessionPhase.catalog,
          onHome: true,
          warningRemaining: Duration.zero,
        );
      }
    }
  }

  void _armIdleTimer() {
    _cancelTimers();
    if (state.onHome || state.phase == KioskSessionPhase.resetting) {
      return;
    }
    if (!ref.read(deviceAuthProvider).isAuthenticated) {
      return;
    }
    final hold = ref.read(kioskSessionHoldProvider);
    if (hold.printing || hold.waiting) {
      return;
    }
    final timeout =
        hold.awaitingConsent ? _policy.consentIdleTimeout : _policy.idleTimeout;
    _idleTimer = Timer(timeout, _onIdleExpired);
  }

  void _onIdleExpired() {
    if (state.phase != KioskSessionPhase.inService) {
      return;
    }
    final hold = ref.read(kioskSessionHoldProvider);
    if (hold.printing || hold.waiting) {
      return;
    }
    state = state.copyWith(
      phase: KioskSessionPhase.warning,
      warningRemaining: _policy.warningDuration,
    );
    _warningTick = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = state.warningRemaining - const Duration(seconds: 1);
      if (left <= Duration.zero) {
        unawaited(endVisitorSession(attract: true));
        return;
      }
      state = state.copyWith(warningRemaining: left);
    });
  }

  void _cancelTimers() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _warningTick?.cancel();
    _warningTick = null;
  }
}
