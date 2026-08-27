import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';

class NearbyKiosk {
  const NearbyKiosk({
    required this.id,
    required this.name,
    required this.siteName,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.address,
    this.lastHeartbeatAt,
  });

  final String id;
  final String name;
  final String siteName;
  final String? address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? lastHeartbeatAt;

  factory NearbyKiosk.fromJson(Map<String, dynamic> json) {
    return NearbyKiosk(
      id: json['id'] as String,
      name: json['name'] as String,
      siteName: json['siteName'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      lastHeartbeatAt: json['lastHeartbeatAt'] as String?,
    );
  }

  String get subtitle {
    final place = (address != null && address!.trim().isNotEmpty)
        ? address!.trim()
        : siteName;
    return place;
  }

  String get distanceLabel {
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }
    if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(2)} km';
    }
    if (distanceKm < 100) {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
    return '${distanceKm.round()} km';
  }
}

class NearbyKiosksState {
  const NearbyKiosksState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.permissionDenied = false,
  });

  final List<NearbyKiosk> items;
  final bool loading;
  final String? error;
  final bool permissionDenied;
}

class NearbyKiosksNotifier extends Notifier<NearbyKiosksState> {
  @override
  NearbyKiosksState build() => const NearbyKiosksState();

  Future<void> load() async {
    state = const NearbyKiosksState(loading: true);
    try {
      final position = await _resolvePosition();
      final api = ref.read(apiClientProvider);
      final result = await api.get(
        '/devices/nearby',
        query: {
          'lat': position.latitude.toString(),
          'lng': position.longitude.toString(),
        },
      );
      final rawItems = (result['items'] as List<dynamic>? ?? const []);
      final items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(NearbyKiosk.fromJson)
          .toList();
      state = NearbyKiosksState(items: items);
    } on _LocationDeniedException {
      state = const NearbyKiosksState(
        permissionDenied: true,
        error: 'Location permission is required to find nearby kiosks.',
      );
    } catch (error) {
      state = NearbyKiosksState(error: error.toString());
    }
  }

  Future<Position> _resolvePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are turned off. Enable GPS and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const _LocationDeniedException();
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }
}

class _LocationDeniedException implements Exception {
  const _LocationDeniedException();
}

final nearbyKiosksProvider =
    NotifierProvider<NearbyKiosksNotifier, NearbyKiosksState>(
  NearbyKiosksNotifier.new,
);
