import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/service_ratings/application/service_ratings_tracker.dart';
import 'package:skp_kiosk/features/service_ratings/presentation/service_rating_prompt.dart';

/// Full-screen rating shell used when leaving a non-print flow (e.g. charging).
class ServiceRatingPage extends ConsumerWidget {
  const ServiceRatingPage({
    super.key,
    required this.serviceKey,
  });

  final String serviceKey;

  void _finish(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KioskShell(
      title: 'Feedback',
      showHome: false,
      body: ServiceRatingPrompt(
        onSkip: () => _finish(context),
        onSubmitted: (stars, feedback) {
          unawaited(
            ref.read(serviceRatingsTrackerProvider).submit(
                  serviceKey,
                  stars,
                  feedback: feedback,
                ),
          );
          _finish(context);
        },
      ),
    );
  }
}
