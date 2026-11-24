import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:skp_mobile/features/fuel_stations/domain/fuel_station.dart';

/// UAT catalog snapshot used when citizen cannot call device-only /fuel-stations.
abstract final class FuelStationsCatalog {
  static const assetPath = 'assets/fuel_stations/catalog.json';

  static List<FuelStation>? _cache;

  static Future<List<FuelStation>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const [];
    }
    final items = decoded['items'];
    if (items is! List) {
      return const [];
    }
    final stations = <FuelStation>[
      for (final item in items)
        if (item is Map)
          FuelStation.fromJson(Map<String, dynamic>.from(item)),
    ];
    _cache = stations;
    return stations;
  }
}
