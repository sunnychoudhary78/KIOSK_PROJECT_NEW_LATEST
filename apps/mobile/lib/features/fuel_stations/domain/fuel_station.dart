enum FuelKind {
  all,
  fuel,
  cng,
  ev;
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

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : 'Fuel station';

  String get displayAddress {
    final value = address?.trim();
    if (value != null && value.isNotEmpty) return value;
    return 'Delhi NCR';
  }

  String get distanceLabel {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(2)} km';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  List<String> get badges {
    return [
      if (petrol) 'Petrol',
      if (diesel) 'Diesel',
      if (cng) 'CNG',
      if (ev) 'EV',
      if (fuelUntyped) 'Fuel',
    ];
  }

  bool matches(FuelKind kind) {
    return switch (kind) {
      FuelKind.all => true,
      FuelKind.fuel => petrol || diesel || fuelUntyped,
      FuelKind.cng => cng,
      FuelKind.ev => ev,
    };
  }

  FuelStation copyWithDistance(double km) {
    return FuelStation(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      distanceKm: km,
      petrol: petrol,
      diesel: diesel,
      cng: cng,
      ev: ev,
      fuelUntyped: fuelUntyped,
      googlePlaceId: googlePlaceId,
    );
  }

  factory FuelStation.fromJson(Map<String, dynamic> json) {
    return FuelStation(
      name: json['name'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      petrol: json['petrol'] == true,
      diesel: json['diesel'] == true,
      cng: json['cng'] == true,
      ev: json['ev'] == true,
      fuelUntyped: json['fuelUntyped'] == true,
      googlePlaceId: json['googlePlaceId'] as String?,
    );
  }
}
