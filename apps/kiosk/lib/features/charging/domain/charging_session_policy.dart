import 'package:skp_kiosk/features/charging/application/charging_state.dart';
import 'package:skp_kiosk/features/charging/domain/charging_phase.dart';

/// Whether visitor session reset should leave the charger running.
///
/// Armed sockets survive Home / other-service navigation and idle attract.
/// Device logout always shuts the relay down.
bool shouldPreserveChargingOnReset({
  required ChargingUiState state,
  required bool isAuthenticated,
}) {
  return isAuthenticated && state.socketArmed;
}

/// Skip [ChargingController.startSession] when reopening the charging route.
bool shouldResumeChargingUi(ChargingUiState state) {
  return state.socketArmed ||
      state.phase == ChargingPhase.done ||
      state.phase == ChargingPhase.error ||
      state.phase == ChargingPhase.watchingAd;
}
