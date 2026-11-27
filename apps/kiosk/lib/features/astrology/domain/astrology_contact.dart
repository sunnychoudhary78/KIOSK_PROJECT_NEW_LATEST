enum AstrologyContactKind { astrologer, pandit, numerology }

class AstrologyContact {
  const AstrologyContact({
    required this.id,
    required this.kind,
    required this.name,
    required this.phone,
    required this.rating,
    this.sortOrder,
    this.address,
    this.degree,
    this.experienceYears,
    this.photoUrl,
  });

  final String id;
  final AstrologyContactKind kind;
  final String name;
  final String phone;
  final double rating;
  final int? sortOrder;
  final String? address;
  final String? degree;
  final int? experienceYears;
  final String? photoUrl;

  factory AstrologyContact.fromJson(Map<String, dynamic> json) {
    final kindRaw = json['kind'] as String? ?? 'astrologer';
    final ratingRaw = json['rating'];
    final rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw?.toString() ?? '') ?? 0;
    final experienceRaw = json['experienceYears'];
    final experienceYears = experienceRaw is num
        ? experienceRaw.toInt()
        : int.tryParse(experienceRaw?.toString() ?? '');
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
      address: json['address']?.toString(),
      degree: json['degree']?.toString(),
      experienceYears: experienceYears,
      photoUrl: json['photoUrl']?.toString(),
    );
  }
}
