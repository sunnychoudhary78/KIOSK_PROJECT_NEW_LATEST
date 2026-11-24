import 'dart:math' as math;

import 'package:skp_mobile/features/fuel_stations/domain/fuel_station.dart';

/// Same constants as apps/api fuel_stations/nearby.ts
const nearbyRadiusKm = 5.0;
const nearbyLimit = 30;
const _earthRadiusKm = 6371.0;

double _toRadians(double degrees) => degrees * math.pi / 180;

/// Great-circle distance — mirrors API `haversineKm`.
double haversineKm(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
}

/// Mirrors API `roundDistanceKm`.
double roundDistanceKm(double km) {
  if (km < 10) return (km * 100).round() / 100;
  if (km < 100) return (km * 10).round() / 10;
  return km.roundToDouble();
}

/// Mirrors API `rankNearbyStations` (without server-side traffic enrich).
List<FuelStation> rankNearbyStations({
  required List<FuelStation> stations,
  required double originLat,
  required double originLng,
  required FuelKind kind,
  double radiusKm = nearbyRadiusKm,
  int limit = nearbyLimit,
}) {
  final ranked = <FuelStation>[];
  for (final station in stations) {
    if (!station.matches(kind)) continue;
    final distanceKm = haversineKm(
      originLat,
      originLng,
      station.latitude,
      station.longitude,
    );
    if (distanceKm > radiusKm) continue;
    ranked.add(station.copyWithDistance(roundDistanceKm(distanceKm)));
  }
  ranked.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  if (ranked.length <= limit) return ranked;
  return ranked.sublist(0, limit);
}
