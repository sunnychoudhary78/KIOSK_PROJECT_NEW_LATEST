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
        ApproachTraffic.clear => 'Road clear',
        ApproachTraffic.moderate => 'Road busy',
        ApproachTraffic.heavy => 'Road very busy',
        ApproachTraffic.unknown => null,
      };
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

  factory FuelStation.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
