import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/application/match_kundali_controller.dart';
import 'package:skp_kiosk/features/astrology/application/my_kundali_controller.dart';
import 'package:skp_kiosk/features/astrology/application/today_periods_controller.dart';
import 'package:skp_kiosk/features/charging/application/charging_controller.dart';
import 'package:skp_kiosk/features/digilocker_print/application/digilocker_controller.dart';
import 'package:skp_kiosk/features/fuel_stations/application/fuel_stations_controller.dart';
import 'package:skp_kiosk/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_kiosk/features/quick_print/application/quick_print_controller.dart';
import 'package:skp_kiosk/features/service_ratings/application/service_ratings_gate.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_controller.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';

typedef VisitorSessionResetFn = Future<void> Function({required bool attract});

/// Per-step cleanup budgets. Exit must never wait longer than these.
const Duration kSessionResetSpoolerTimeout = Duration(seconds: 5);
const Duration kSessionResetDigilockerTimeout = Duration(seconds: 5);
const Duration kSessionResetQuickPrintTimeout = Duration(seconds: 5);
const Duration kSessionResetChargingTimeout = Duration(seconds: 8);
const Duration kSessionResetTempWipeTimeout = Duration(seconds: 3);

final visitorSessionResetProvider = Provider<VisitorSessionResetFn>((ref) {
  return ({required bool attract}) =>
      resetVisitorSession(ref, attract: attract);
});

/// Wipe visitor PII and return to the catalog. Does not touch device auth.
///
/// Navigation to the catalog happens first so Back/Home cannot hang on
/// printer native calls or outbound API cancels. Cleanup is best-effort.
Future<void> resetVisitorSession(Ref ref, {required bool attract}) async {
  AppLogger.info('session_reset_start attract=$attract');

  // Unlock print immediately so Home never leaves "already running".
  try {
    ref.read(printCoordinatorProvider).abortAndReset();
  } catch (_) {}

  // Citizen exit first — PopScope needs a frame so canPop can become true.
  WidgetsBinding.instance.scheduleFrame();
  await WidgetsBinding.instance.endOfFrame;
  kioskNavigatorKey.currentState?.popUntil((route) => route.isFirst);

  imageCache.clear();
  imageCache.clearLiveImages();

  // Best-effort cleanup with hard deadlines — never block forever.
  await bestEffortTimed(
    'spooler_clear',
    () async {
      try {
        await ref.read(printCoordinatorProvider).clearPendingSpoolerWork();
      } catch (_) {}
    },
    kSessionResetSpoolerTimeout,
  );

  if (ref.exists(digilockerControllerProvider)) {
    await bestEffortTimed(
      'digilocker_end',
      () => ref.read(digilockerControllerProvider.notifier).endSession(),
      kSessionResetDigilockerTimeout,
    );
  }
  if (ref.exists(otpPrintControllerProvider)) {
    try {
      ref.read(otpPrintControllerProvider.notifier).reset();
    } catch (_) {}
  }
  if (ref.exists(quickPrintControllerProvider)) {
    await bestEffortTimed(
      'quick_print_reset',
      () => ref.read(quickPrintControllerProvider.notifier).reset(),
      kSessionResetQuickPrintTimeout,
    );
  }
  if (ref.exists(chargingControllerProvider)) {
    await bestEffortTimed(
      'charging_shutdown',
      () => ref.read(chargingControllerProvider.notifier).forceShutdown(),
      kSessionResetChargingTimeout,
    );
  }

  ref.invalidate(digilockerControllerProvider);
  ref.invalidate(otpPrintControllerProvider);
  ref.invalidate(quickPrintControllerProvider);
  ref.invalidate(astrologyControllerProvider);
  ref.invalidate(myKundaliControllerProvider);
  ref.invalidate(matchKundaliControllerProvider);
  ref.invalidate(todayPeriodsControllerProvider);
  ref.invalidate(wellBeingControllerProvider);
  ref.invalidate(chargingControllerProvider);
  ref.invalidate(fuelStationsControllerProvider);

  try {
    ref.read(serviceRatingsGateProvider.notifier).clear();
  } catch (_) {}

  await bestEffortTimed(
    'wipe_digilocker_temp',
    wipeDigilockerTempDir,
    kSessionResetTempWipeTimeout,
  );

  if (!ref.mounted) {
    AppLogger.info('session_reset_done (unmounted)');
    return;
  }
  final ads = ref.read(adsControllerProvider.notifier);
  if (attract) {
    ads.showIdleNow();
  } else {
    ads.resetIdleTimer();
  }
  AppLogger.info('session_reset_done attract=$attract');
}

/// Run [fn] with a hard deadline. Logs and swallows timeout/errors.
Future<void> bestEffortTimed(
  String name,
  Future<void> Function() fn,
  Duration limit,
) async {
  try {
    await fn().timeout(limit);
  } on TimeoutException {
    AppLogger.warn(
      'session_reset_step_timeout name=$name limitMs=${limit.inMilliseconds}',
    );
  } catch (error) {
    AppLogger.warn('session_reset_step_failed name=$name error=$error');
  }
}

Future<void> wipeDigilockerTempDir() async {
  try {
    final dir = Directory(p.join(Directory.systemTemp.path, 'skp_digilocker'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  } catch (_) {}
}
