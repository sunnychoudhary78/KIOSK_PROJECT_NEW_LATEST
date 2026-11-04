import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/service_analytics/data/service_analytics_repository.dart';
import 'package:skp_kiosk/features/service_analytics/domain/service_event_keys.dart';

final serviceAnalyticsRepositoryProvider =
    Provider<ServiceAnalyticsRepository>((ref) {
  return ServiceAnalyticsRepository(ref.watch(apiClientProvider));
});

final serviceAnalyticsTrackerProvider = Provider<ServiceAnalyticsTracker>((ref) {
  return ServiceAnalyticsTracker(ref);
});

class ServiceAnalyticsTracker {
  ServiceAnalyticsTracker(this._ref);

  final Ref _ref;

  Future<void> track(
    String eventKey, {
    Map<String, dynamic>? metadata,
  }) async {
    if (eventKey.isEmpty) {
      return;
    }
    if (!_ref.read(deviceAuthProvider).isAuthenticated) {
      return;
    }
    try {
      await _ref.read(serviceAnalyticsRepositoryProvider).reportEvents([
        {
          'eventKey': eventKey,
          'occurredAt': DateTime.now().toUtc().toIso8601String(),
          if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
        },
      ]);
    } catch (_) {
      // Non-blocking for UX
    }
  }

  void trackRoute(RouteSettings settings) {
    final key = ServiceEventKeys.fromRoute(settings);
    if (key == null) {
      return;
    }
    // Fire without awaiting so navigation stays snappy.
    // ignore: discarded_futures
    track(key);
  }
}
