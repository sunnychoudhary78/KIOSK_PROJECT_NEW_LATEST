import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/charging/application/charging_state.dart';
import 'package:skp_kiosk/features/charging/domain/charging_monitor.dart';
import 'package:skp_kiosk/features/charging/domain/charging_phase.dart';
import 'package:skp_kiosk/features/charging/domain/charging_session_policy.dart';

void main() {
  group('shouldPreserveChargingOnReset', () {
    test('preserves when authenticated and waiting for phone', () {
      final state = ChargingMonitor.onRelayArmed(ChargingUiState.initial());
      expect(state.socketArmed, isTrue);
      expect(
        shouldPreserveChargingOnReset(state: state, isAuthenticated: true),
        isTrue,
      );
    });

    test('preserves when authenticated and charging', () {
      final armed = ChargingMonitor.onRelayArmed(ChargingUiState.initial());
      final state = armed.copyWith(phase: ChargingPhase.charging);
      expect(
        shouldPreserveChargingOnReset(state: state, isAuthenticated: true),
        isTrue,
      );
    });

    test('does not preserve when unauthenticated', () {
      final state = ChargingMonitor.onRelayArmed(ChargingUiState.initial());
      expect(
        shouldPreserveChargingOnReset(state: state, isAuthenticated: false),
        isFalse,
      );
    });

    test('does not preserve when socket is not armed', () {
      expect(
        shouldPreserveChargingOnReset(
          state: ChargingUiState.initial(),
          isAuthenticated: true,
        ),
        isFalse,
      );
      expect(
        shouldPreserveChargingOnReset(
          state: ChargingUiState.initial().copyWith(phase: ChargingPhase.done),
          isAuthenticated: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldResumeChargingUi', () {
    test('resumes armed, done, error, and ad phases', () {
      expect(
        shouldResumeChargingUi(ChargingMonitor.onRelayArmed(ChargingUiState.initial())),
        isTrue,
      );
      expect(
        shouldResumeChargingUi(
          ChargingUiState.initial().copyWith(phase: ChargingPhase.done),
        ),
        isTrue,
      );
      expect(
        shouldResumeChargingUi(
          ChargingUiState.initial().copyWith(phase: ChargingPhase.error),
        ),
        isTrue,
      );
      expect(
        shouldResumeChargingUi(
          ChargingUiState.initial().copyWith(phase: ChargingPhase.watchingAd),
        ),
        isTrue,
      );
    });

    test('starts fresh only from a fresh connecting state', () {
      expect(shouldResumeChargingUi(ChargingUiState.initial()), isFalse);
    });
  });
}
