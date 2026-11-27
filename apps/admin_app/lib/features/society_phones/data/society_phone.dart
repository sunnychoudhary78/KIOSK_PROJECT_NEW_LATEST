class SocietyQuota {
  const SocietyQuota({
    required this.period,
    required this.freePages,
  });

  final String period;
  /// Combined free pages shared by B/W and color.
  final int freePages;

  int get freeBwPages => freePages;
  int get freeColorPages => freePages;

  static const defaults = SocietyQuota(
    period: 'daily',
    freePages: 5,
  );

  factory SocietyQuota.fromJson(Map<String, dynamic> json) {
    final period = json['period']?.toString();
    final freePagesRaw = json['freePages'];
    final freePages = freePagesRaw != null
        ? _pages(freePagesRaw, defaults.freePages)
        : _pages(json['freeBwPages'], 0) + _pages(json['freeColorPages'], 0);
    return SocietyQuota(
      period: period == 'weekly' || period == 'monthly' ? period! : 'daily',
      freePages: freePages > 0 ? freePages : defaults.freePages,
    );
  }

  Map<String, dynamic> toJson() => {
        'period': period,
        'freePages': freePages,
        'freeBwPages': freePages,
        'freeColorPages': freePages,
        'combined': true,
      };

  @override
  bool operator ==(Object other) {
    return other is SocietyQuota &&
        other.period == period &&
        other.freePages == freePages;
  }

  @override
  int get hashCode => Object.hash(period, freePages);
}

class SocietyPhone {
  const SocietyPhone({
    required this.id,
    required this.phone,
    required this.name,
    required this.societyName,
    required this.createdAt,
  });

  final String id;
  final String phone;
  final String name;
  final String societyName;
  final String createdAt;

  factory SocietyPhone.fromJson(Map<String, dynamic> json) {
    return SocietyPhone(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      societyName: json['societyName']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class SocietyPhoneList {
  const SocietyPhoneList({required this.total, required this.items});

  final int total;
  final List<SocietyPhone> items;
}

int? parseQuotaPages(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null || value < 0 || value > 500) return null;
  return value;
}

String? validateSocietyPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
    return 'Enter a valid 10-digit Indian mobile number.';
  }
  return null;
}

String? validateSocietyPersonName(String raw) {
  final name = raw.trim();
  if (name.length > 120) return 'Person name must be 120 characters or fewer.';
  return null;
}

String? validateSocietyName(String raw) {
  final name = raw.trim();
  if (name.length > 160) return 'Society name must be 160 characters or fewer.';
  return null;
}

int _pages(Object? raw, int fallback) {
  if (raw is! num) return fallback;
  final value = raw.toInt();
  if (value < 0 || value > 500) return fallback;
  return value;
}
