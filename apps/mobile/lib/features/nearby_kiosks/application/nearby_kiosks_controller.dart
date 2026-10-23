import 'package:flutter/foundation.dart';
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
    this.maxPagesPerSession = 10,
    this.freePagesPerSession = 5,
    this.extraPageChargeRupees = 10,
    this.freeColorPagesPerSession = 0,
    this.extraColorPageChargeRupees = 20,
    this.freeDisabledNow = false,
  });

  final String id;
  final String name;
  final String siteName;
  final String? address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? lastHeartbeatAt;
  final int maxPagesPerSession;
  final int freePagesPerSession;
  final int extraPageChargeRupees;
  final int freeColorPagesPerSession;
  final int extraColorPageChargeRupees;
  final bool freeDisabledNow;

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
      maxPagesPerSession: _asInt(json['maxPagesPerSession'], 10),
      freePagesPerSession: _asInt(json['freePagesPerSession'], 5),
      extraPageChargeRupees: _asInt(json['extraPageChargeRupees'], 10),
      freeColorPagesPerSession: _asInt(json['freeColorPagesPerSession'], 0),
      extraColorPageChargeRupees: _asInt(json['extraColorPageChargeRupees'], 20),
      freeDisabledNow: json['freeDisabledNow'] as bool? ?? false,
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
    this.permissionDeniedForever = false,
    this.locationServicesDisabled = false,
  });

  final List<NearbyKiosk> items;
  final bool loading;
  final String? error;
  final bool permissionDenied;
  final bool permissionDeniedForever;
  final bool locationServicesDisabled;

  bool get needsSystemSettings =>
      locationServicesDisabled || permissionDeniedForever;
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
    } on _LocationDeniedException catch (error) {
      state = NearbyKiosksState(
        permissionDenied: true,
        permissionDeniedForever: error.forever,
      );
    } on _LocationServicesException {
      state = const NearbyKiosksState(locationServicesDisabled: true);
    } catch (error) {
      state = NearbyKiosksState(error: error.toString());
    }
  }

  Future<void> openLocationRecovery() {
    if (state.locationServicesDisabled) {
      return Geolocator.openLocationSettings();
    }
    return Geolocator.openAppSettings();
  }

  Future<Position> _resolvePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const _LocationServicesException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _LocationDeniedException(forever: true);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const _LocationDeniedException(forever: false);
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
  const _LocationDeniedException({required this.forever});

  final bool forever;
}

class _LocationServicesException implements Exception {
  const _LocationServicesException();
}

/// Apple Maps on iOS. Google Maps directions on Android.
Uri kioskDirectionsUri({required double latitude, required double longitude}) {
  final destination = '$latitude,$longitude';
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return Uri.https('maps.apple.com', '/', {'daddr': destination});
  }
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': destination,
  });
}

final nearbyKiosksProvider =
    NotifierProvider<NearbyKiosksNotifier, NearbyKiosksState>(
  NearbyKiosksNotifier.new,
);

int _asInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}
