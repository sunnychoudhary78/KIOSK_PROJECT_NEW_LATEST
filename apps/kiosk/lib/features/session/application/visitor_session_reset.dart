import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/digilocker_print/application/digilocker_controller.dart';
import 'package:skp_kiosk/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_controller.dart';

typedef VisitorSessionResetFn = Future<void> Function({required bool attract});

final visitorSessionResetProvider = Provider<VisitorSessionResetFn>((ref) {
  return ({required bool attract}) => resetVisitorSession(ref, attract: attract);
});

/// Wipe visitor PII and return to the catalog. Does not touch device auth.
Future<void> resetVisitorSession(
  Ref ref, {
  required bool attract,
}) async {
  if (ref.exists(digilockerControllerProvider)) {
    try {
      await ref.read(digilockerControllerProvider.notifier).endSession();
    } catch (_) {}
  }
  if (ref.exists(otpPrintControllerProvider)) {
    try {
      ref.read(otpPrintControllerProvider.notifier).reset();
    } catch (_) {}
  }

  // Allow PopScope(canPop: false) to rebuild as canPop: true before we pop.
  WidgetsBinding.instance.scheduleFrame();
  await WidgetsBinding.instance.endOfFrame;

  kioskNavigatorKey.currentState?.popUntil((route) => route.isFirst);

  ref.invalidate(digilockerControllerProvider);
  ref.invalidate(otpPrintControllerProvider);
  ref.invalidate(astrologyControllerProvider);
  ref.invalidate(wellBeingControllerProvider);

  imageCache.clear();
  imageCache.clearLiveImages();

  await wipeDigilockerTempDir();

  if (!ref.mounted) {
    return;
  }
  final ads = ref.read(adsControllerProvider.notifier);
  if (attract) {
    ads.showIdleNow();
  } else {
    ads.resetIdleTimer();
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
