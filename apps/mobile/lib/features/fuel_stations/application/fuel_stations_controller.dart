import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skp_mobile/core/network/api_client.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/fuel_stations/data/fuel_stations_catalog.dart';
import 'package:skp_mobile/features/fuel_stations/domain/fuel_station.dart';
import 'package:skp_mobile/features/fuel_stations/domain/nearby_rank.dart';

class FuelStationsState {
  const FuelStationsState({
    this.items = const [],
    // Match kiosk default filter (Petrol/Diesel).
    this.kind = FuelKind.fuel,
    this.loading = false,
    this.error,
    this.permissionDenied = false,
    this.permissionDeniedForever = false,
    this.locationServicesDisabled = false,
  });

  final List<FuelStation> items;
  final FuelKind kind;
  final bool loading;
  final String? error;
  final bool permissionDenied;
  final bool permissionDeniedForever;
  final bool locationServicesDisabled;

  bool get needsSystemSettings =>
      locationServicesDisabled || permissionDeniedForever;
}

class FuelStationsNotifier extends Notifier<FuelStationsState> {
  int _request = 0;

  @override
  FuelStationsState build() => const FuelStationsState();

  Future<void> load({FuelKind? kind}) async {
    final selected = kind ?? state.kind;
    final request = ++_request;
    state = FuelStationsState(loading: true, kind: selected);
    try {
      final position = await _resolvePosition();
      if (request != _request) return;

      try {
        final result = await ref.read(apiClientProvider).get(
          '/fuel-stations',
          query: {
            'kind': selected.name,
            'limit': '$nearbyLimit',
          },
        );
        if (request != _request) return;
        state = FuelStationsState(
          items: _parseApiItems(result),
          kind: selected,
        );
        return;
      } on ApiException catch (error) {
        if (!_shouldUseCatalog(error)) {
          if (request != _request) return;
          state = FuelStationsState(kind: selected, error: error.toString());
          return;
        }
      }

      // Same ranking as desktop API: haversine + 5 km + kind filter + top 30.
      final catalog = await FuelStationsCatalog.load();
      if (request != _request) return;
      final ranked = rankNearbyStations(
        stations: catalog,
        originLat: position.latitude,
        originLng: position.longitude,
        kind: selected,
      );
      state = FuelStationsState(items: ranked, kind: selected);
    } on _LocationDeniedException catch (error) {
      if (request != _request) return;
      state = FuelStationsState(
        kind: selected,
        permissionDenied: true,
        permissionDeniedForever: error.forever,
      );
    } on _LocationServicesException {
      if (request != _request) return;
      state = FuelStationsState(
        kind: selected,
        locationServicesDisabled: true,
      );
    } catch (error) {
      if (request != _request) return;
      state = FuelStationsState(kind: selected, error: error.toString());
    }
  }

  Future<void> selectKind(FuelKind kind) => load(kind: kind);

  Future<void> openLocationRecovery() {
    if (state.locationServicesDisabled) {
      return Geolocator.openLocationSettings();
    }
    return Geolocator.openAppSettings();
  }

  bool _shouldUseCatalog(ApiException error) {
    if (error.statusCode == 401 || error.statusCode == 403) return true;
    final message = error.message.toLowerCase();
    return message.contains('principal') ||
        message.contains('device') ||
        error.code == 'forbidden' ||
        error.code == 'unauthorized';
  }

  List<FuelStation> _parseApiItems(Map<String, dynamic> result) {
    final raw = result['items'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) FuelStation.fromJson(Map<String, dynamic>.from(item)),
    ];
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

final fuelStationsProvider =
    NotifierProvider<FuelStationsNotifier, FuelStationsState>(
  FuelStationsNotifier.new,
);
