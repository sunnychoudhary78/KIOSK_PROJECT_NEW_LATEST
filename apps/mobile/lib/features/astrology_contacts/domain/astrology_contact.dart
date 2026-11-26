enum AstrologyContactKind { astrologer, pandit, numerology }

class AstrologyContact {
  const AstrologyContact({
    required this.id,
    required this.kind,
    required this.name,
    required this.phone,
    required this.rating,
    this.sortOrder = 0,
  });

  final String id;
  final AstrologyContactKind kind;
  final String name;
  final String phone;
  final double rating;
  final int sortOrder;

  String get displayPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    }
    return phone;
  }

  String get dialDigits {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return digits.isEmpty ? phone : digits;
  }

  factory AstrologyContact.fromJson(Map<String, dynamic> json) {
    final kindRaw = json['kind']?.toString() ?? 'astrologer';
    return AstrologyContact(
      id: json['id']?.toString() ?? '',
      kind: switch (kindRaw) {
        'pandit' => AstrologyContactKind.pandit,
        'numerology' => AstrologyContactKind.numerology,
        _ => AstrologyContactKind.astrologer,
      },
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
