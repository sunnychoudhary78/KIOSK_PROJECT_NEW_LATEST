class LocalServiceContact {
  const LocalServiceContact({
    required this.id,
    required this.name,
    required this.phone,
    this.rating = 0,
    this.pinned = false,
    this.address,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String phone;
  final double rating;
  final bool pinned;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String? photoUrl;

  factory LocalServiceContact.fromJson(Map<String, dynamic> json) {
    final ratingRaw = json['rating'];
    final rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw?.toString() ?? '') ?? 0;
    return LocalServiceContact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      rating: rating.clamp(0, 5),
      pinned: json['pinned'] == true,
      address: json['address']?.toString(),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      distanceKm: _asDouble(json['distanceKm']),
      photoUrl: json['photoUrl']?.toString(),
    );
  }
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

class LocalServiceCategory {
  const LocalServiceCategory({
    required this.slug,
    required this.name,
    required this.contacts,
  });

  final String slug;
  final String name;
  final List<LocalServiceContact> contacts;

  factory LocalServiceCategory.fromJson(Map<String, dynamic> json) {
    final raw = json['contacts'];
    final contacts = <LocalServiceContact>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          contacts.add(LocalServiceContact.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    // Defensive client sort: pinned → distance → rating → name (API already sorts this way).
    contacts.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final da = a.distanceKm ?? double.infinity;
      final db = b.distanceKm ?? double.infinity;
      final byDistance = da.compareTo(db);
      if (byDistance != 0) return byDistance;
      final byRating = b.rating.compareTo(a.rating);
      if (byRating != 0) return byRating;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return LocalServiceCategory(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contacts: contacts,
    );
  }
}
