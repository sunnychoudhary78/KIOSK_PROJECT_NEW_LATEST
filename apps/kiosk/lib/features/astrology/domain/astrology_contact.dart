enum AstrologyContactKind { astrologer, pandit, numerology }

class AstrologyContact {
  const AstrologyContact({
    required this.id,
    required this.kind,
    required this.name,
    required this.phone,
    required this.rating,
    this.sortOrder,
    this.photoUrl,
  });

  final String id;
  final AstrologyContactKind kind;
  final String name;
  final String phone;
  final double rating;
  final int? sortOrder;
  final String? photoUrl;

  factory AstrologyContact.fromJson(Map<String, dynamic> json) {
    final kindRaw = json['kind'] as String? ?? 'astrologer';
    final ratingRaw = json['rating'];
    final rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw?.toString() ?? '') ?? 0;
    return AstrologyContact(
      id: json['id'] as String? ?? '',
      kind: switch (kindRaw) {
        'pandit' => AstrologyContactKind.pandit,
        'numerology' => AstrologyContactKind.numerology,
        _ => AstrologyContactKind.astrologer,
      },
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      rating: rating.clamp(0, 5),
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
      photoUrl: json['photoUrl']?.toString(),
    );
  }
}
