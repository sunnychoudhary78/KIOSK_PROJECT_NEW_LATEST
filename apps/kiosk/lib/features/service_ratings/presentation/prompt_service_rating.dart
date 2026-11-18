import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/features/service_ratings/application/service_ratings_gate.dart';
import 'package:skp_kiosk/features/service_ratings/presentation/service_rating_page.dart';

/// Shows [ServiceRatingPage] once per [family] in the current visitor session.
Future<void> promptServiceRatingIfNeeded(
  BuildContext context,
  WidgetRef ref, {
  required String family,
  required String serviceKey,
}) async {
  final gate = ref.read(serviceRatingsGateProvider.notifier);
  if (!gate.shouldPrompt(family)) {
    return;
  }
  // Mark before showing so skip/timeout still counts as asked.
  gate.markPrompted(family);
  if (!context.mounted) {
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ServiceRatingPage(serviceKey: serviceKey),
    ),
  );
}
