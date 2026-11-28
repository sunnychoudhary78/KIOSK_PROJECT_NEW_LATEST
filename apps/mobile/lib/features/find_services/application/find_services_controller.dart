import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skp_mobile/core/network/api_client.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/find_services/domain/local_service.dart';

class FindServicesState {
  const FindServicesState({
    this.categories = const [],
    this.loading = false,
    this.error,
  });

  final List<LocalServiceCategory> categories;
  final bool loading;
  final String? error;
}

class FindServicesNotifier extends Notifier<FindServicesState> {
  @override
  FindServicesState build() => const FindServicesState();

  /// API caps nearby radius at 50 km. Use the max so admin contacts with
  /// coordinates are not hidden by the old 5 km filter.
  static const _maxNearbyRadiusKm = '50';

  /// Fallback origin only when GPS is unavailable. Nearby API requires lat/lng.
  static const _fallbackLat = '28.6139';
  static const _fallbackLng = '77.2090';

  Future<void> load() async {
    state = const FindServicesState(loading: true);
    try {
      // Prefer full admin list when citizen is allowed on this route.
      final fullList = await _tryLoadFullList();
      if (fullList != null) {
        state = FindServicesState(categories: fullList);
        return;
      }

      final position = await _tryResolvePosition();
      final result = await ref.read(apiClientProvider).get(
        '/local-services/nearby',
        query: {
          'lat': position?.latitude.toString() ?? _fallbackLat,
          'lng': position?.longitude.toString() ?? _fallbackLng,
          'radiusKm': _maxNearbyRadiusKm,
        },
      );
      state = FindServicesState(categories: _parseCategories(result));
    } on ApiException catch (error) {
      state = FindServicesState(error: error.toString());
    } catch (error) {
      state = FindServicesState(error: error.toString());
    }
  }

  /// Returns parsed categories from GET /local-services, or null if forbidden.
  Future<List<LocalServiceCategory>?> _tryLoadFullList() async {
    try {
      final result = await ref.read(apiClientProvider).get('/local-services');
      return _parseCategories(result);
    } on ApiException catch (error) {
      if (error.statusCode == 403 ||
          error.statusCode == 401 ||
          error.statusCode == 404 ||
          (error.code ?? '').toLowerCase() == 'forbidden' ||
          error.message.toLowerCase().contains('principal type not allowed')) {
        return null;
      }
      rethrow;
    }
  }

  Future<Position?> _tryResolvePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  List<LocalServiceCategory> _parseCategories(Map<String, dynamic> result) {
    final raw = result['categories'];
    final categories = <LocalServiceCategory>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final category = LocalServiceCategory.fromJson(
            Map<String, dynamic>.from(item),
          );
          // Show every active admin service, even if contacts/geo are empty.
          if (category.isActive) {
            categories.add(category);
          }
        }
      }
    }
    return categories;
  }
}

final findServicesProvider =
    NotifierProvider<FindServicesNotifier, FindServicesState>(
  FindServicesNotifier.new,
);
