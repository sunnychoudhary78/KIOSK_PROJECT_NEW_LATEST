class LocalServiceContact {
  const LocalServiceContact({
    required this.id,
    required this.name,
    required this.phone,
    this.rating = 0,
    this.topRank,
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
  /// Admin Top 5 slot (1–5). Null = not featured.
  final int? topRank;
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
    final topRankRaw = json['topRank'];
    final topRank = topRankRaw is num
        ? topRankRaw.toInt()
        : int.tryParse(topRankRaw?.toString() ?? '');
    return LocalServiceContact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      rating: rating.clamp(0, 5),
      topRank: topRank != null && topRank >= 1 && topRank <= 5 ? topRank : null,
      pinned: json['pinned'] == true || topRank != null,
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
    // Defensive client sort: Top 5 → distance → rating → name (API already sorts this way).
    contacts.sort((a, b) {
      final ra = a.topRank ?? 1 << 30;
      final rb = b.topRank ?? 1 << 30;
      if (ra != rb) return ra.compareTo(rb);
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
