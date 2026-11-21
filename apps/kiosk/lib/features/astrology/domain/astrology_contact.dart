enum AstrologyContactKind { astrologer, pandit }

class AstrologyContact {
  const AstrologyContact({
    required this.id,
    required this.kind,
    required this.name,
    required this.phone,
    required this.rating,
    this.sortOrder,
  });

  final String id;
  final AstrologyContactKind kind;
  final String name;
  final String phone;
  final double rating;
  final int? sortOrder;

  factory AstrologyContact.fromJson(Map<String, dynamic> json) {
    final kindRaw = json['kind'] as String? ?? 'astrologer';
    return AstrologyContact(
      id: json['id'] as String? ?? '',
      kind: kindRaw == 'pandit'
          ? AstrologyContactKind.pandit
          : AstrologyContactKind.astrologer,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
    );
  }
}
