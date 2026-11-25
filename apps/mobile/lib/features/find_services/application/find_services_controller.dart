import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skp_mobile/core/network/api_client.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/find_services/data/find_services_catalog.dart';
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

  Future<void> load() async {
    state = const FindServicesState(loading: true);
    try {
      final position = await _resolvePosition();
      final result = await ref.read(apiClientProvider).get(
        '/local-services/nearby',
        query: {
          'lat': position.latitude.toString(),
          'lng': position.longitude.toString(),
          'radiusKm': '5',
        },
      );
      state = FindServicesState(categories: _parseCategories(result));
    } on ApiException catch (error) {
      // Offline / API gap: use bundled catalog so the feature still works.
      if (_shouldUseBundledCatalog(error)) {
        state = const FindServicesState(
          categories: FindServicesCatalog.categories,
        );
        return;
      }
      state = FindServicesState(error: error.toString());
    } catch (error) {
      // Location denied or unavailable → bundled catalog.
      state = const FindServicesState(
        categories: FindServicesCatalog.categories,
      );
    }
  }

  Future<Position> _resolvePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('location_services_disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      throw StateError('location_permission_denied');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  bool _shouldUseBundledCatalog(ApiException error) {
    if (error.statusCode == 403 || error.statusCode == 404) return true;
    final message = error.message.toLowerCase();
    return message.contains('principal type not allowed') ||
        error.code == 'forbidden';
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
