enum FuelKind {
  all,
  fuel,
  cng,
  ev;

  String get label => switch (this) {
        FuelKind.all => 'All',
        FuelKind.fuel => 'Fuel',
        FuelKind.cng => 'CNG',
        FuelKind.ev => 'EV',
      };
}

enum ApproachTraffic {
  clear,
  moderate,
  heavy,
  unknown;

  static ApproachTraffic? tryParse(Object? raw) {
    return switch (raw) {
      'clear' => ApproachTraffic.clear,
      'moderate' => ApproachTraffic.moderate,
      'heavy' => ApproachTraffic.heavy,
      'unknown' => ApproachTraffic.unknown,
      _ => null,
    };
  }

  String? get badgeLabel => switch (this) {
        ApproachTraffic.clear => 'Clear',
        ApproachTraffic.moderate => 'Busy',
        ApproachTraffic.heavy => 'Very busy',
        ApproachTraffic.unknown => null,
      };
}

enum RouteTrafficSpeed {
  normal,
  slow,
  trafficJam;

  static RouteTrafficSpeed tryParse(Object? raw) {
    return switch (raw) {
      'SLOW' => RouteTrafficSpeed.slow,
      'TRAFFIC_JAM' => RouteTrafficSpeed.trafficJam,
      _ => RouteTrafficSpeed.normal,
    };
  }
}

class RouteTrafficSegment {
  const RouteTrafficSegment({required this.speed, required this.fraction});

  final RouteTrafficSpeed speed;
  final double fraction;

  factory RouteTrafficSegment.fromJson(Map<String, dynamic> json) {
    return RouteTrafficSegment(
      speed: RouteTrafficSpeed.tryParse(json['speed']),
      fraction: _parseFraction(json['fraction']),
    );
  }

  static double _parseFraction(Object? raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw) ?? 0;
    }
    return 0;
  }
}

class FuelStation {
  const FuelStation({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.petrol,
    required this.diesel,
    required this.cng,
    required this.ev,
    required this.fuelUntyped,
    this.googlePlaceId,
    this.approachTraffic,
    this.approachWaitMin,
    this.driveDistanceKm,
    this.driveDurationMin,
    this.routeTrafficSegments = const [],
    this.bestNow = false,
  });

  final String? name;
  final String? address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final bool petrol;
  final bool diesel;
  final bool cng;
  final bool ev;
  final bool fuelUntyped;
  final String? googlePlaceId;
  final ApproachTraffic? approachTraffic;
  final int? approachWaitMin;
  final double? driveDistanceKm;
  final int? driveDurationMin;
  final List<RouteTrafficSegment> routeTrafficSegments;
  final bool bestNow;

  /// Segments for the traffic bar: prefer API route data, else status fallback.
  List<RouteTrafficSegment> get displayTrafficSegments {
    if (routeTrafficSegments.isNotEmpty) {
      return routeTrafficSegments;
    }
    return switch (approachTraffic) {
      ApproachTraffic.clear => const [
          RouteTrafficSegment(speed: RouteTrafficSpeed.normal, fraction: 1),
        ],
      ApproachTraffic.moderate => const [
          RouteTrafficSegment(speed: RouteTrafficSpeed.normal, fraction: 0.7),
          RouteTrafficSegment(speed: RouteTrafficSpeed.slow, fraction: 0.3),
        ],
      ApproachTraffic.heavy => const [
          RouteTrafficSegment(speed: RouteTrafficSpeed.normal, fraction: 0.5),
          RouteTrafficSegment(speed: RouteTrafficSpeed.trafficJam, fraction: 0.5),
        ],
      ApproachTraffic.unknown || null => const [],
    };
  }

  String get directionsUrl {
    final pin = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final placeId = googlePlaceId;
    if (placeId == null || placeId.isEmpty) {
      return pin;
    }
    return '$pin&query_place_id=${Uri.encodeQueryComponent(placeId)}';
  }

  List<String> get badges {
    final labels = <String>[
      if (petrol) 'Petrol',
      if (diesel) 'Diesel',
      if (cng) 'CNG',
      if (ev) 'EV',
      if (fuelUntyped) 'Fuel',
    ];
    return labels;
  }

  static List<RouteTrafficSegment> _parseSegments(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    final out = <RouteTrafficSegment>[];
    for (final row in raw) {
      if (row is! Map) {
        continue;
      }
      final segment = RouteTrafficSegment.fromJson(Map<String, dynamic>.from(row));
      if (segment.fraction > 0) {
        out.add(segment);
      }
    }
    return out;
  }

  factory FuelStation.fromJson(Map<String, dynamic> json) {
    final waitRaw = json['approachWaitMin'];
    final driveKmRaw = json['driveDistanceKm'];
    final driveMinRaw = json['driveDurationMin'];
    return FuelStation(
      name: json['name'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      petrol: json['petrol'] == true,
      diesel: json['diesel'] == true,
      cng: json['cng'] == true,
      ev: json['ev'] == true,
      fuelUntyped: json['fuelUntyped'] == true,
      googlePlaceId: json['googlePlaceId'] as String?,
      approachTraffic: ApproachTraffic.tryParse(json['approachTraffic']),
      approachWaitMin: waitRaw is num ? waitRaw.toInt() : null,
      driveDistanceKm: driveKmRaw is num ? driveKmRaw.toDouble() : null,
      driveDurationMin: driveMinRaw is num ? driveMinRaw.toInt() : null,
      routeTrafficSegments: _parseSegments(json['routeTrafficSegments']),
      bestNow: json['bestNow'] == true,
    );
  }
}
