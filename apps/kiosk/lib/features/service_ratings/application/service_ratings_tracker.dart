import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/service_ratings/data/service_ratings_repository.dart';

final serviceRatingsRepositoryProvider =
    Provider<ServiceRatingsRepository>((ref) {
  return ServiceRatingsRepository(ref.watch(apiClientProvider));
});

final serviceRatingsTrackerProvider = Provider<ServiceRatingsTracker>((ref) {
  return ServiceRatingsTracker(ref);
});

class ServiceRatingsTracker {
  ServiceRatingsTracker(this._ref);

  final Ref _ref;

  Future<void> submit(String serviceKey, int stars) async {
    if (serviceKey.isEmpty || stars < 1 || stars > 5) {
      return;
    }
    if (!_ref.read(deviceAuthProvider).isAuthenticated) {
      return;
    }
    try {
      await _ref.read(serviceRatingsRepositoryProvider).reportRatings([
        {
          'serviceKey': serviceKey,
          'stars': stars,
          'occurredAt': DateTime.now().toUtc().toIso8601String(),
        },
      ]);
    } catch (_) {
      // Non-blocking for UX
    }
  }
}
