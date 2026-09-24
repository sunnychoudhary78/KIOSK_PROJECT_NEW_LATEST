import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/navigation/nav_tab.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_controller.dart';

Future<void> openPrintSession(
  BuildContext context,
  WidgetRef ref,
  OtpChallenge challenge,
) async {
  await ref.read(otpPrintControllerProvider.notifier).loadChallenge(challenge.id);
  if (!context.mounted) return;
  final loaded = ref.read(otpPrintControllerProvider).asData?.value ?? challenge;
  if (loaded.status == 'awaiting_payment' && !loaded.isExpired) {
    await Navigator.of(context).pushNamed(AppRoutes.otpPrintPayment);
    return;
  }
  if (loaded.status == 'pending' || loaded.otpSent) {
    await Navigator.of(context).pushNamed(AppRoutes.otpPrintSuccess);
  }
}

void goToNearbyTab(BuildContext context, WidgetRef ref) {
  ref.read(navTabProvider.notifier).select(NavTabs.nearby);
  Navigator.of(context).popUntil((route) => route.isFirst);
}
