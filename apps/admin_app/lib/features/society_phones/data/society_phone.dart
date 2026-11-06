class SocietyQuota {
  const SocietyQuota({
    required this.period,
    required this.freeBwPages,
    required this.freeColorPages,
  });

  final String period;
  final int freeBwPages;
  final int freeColorPages;

  static const defaults = SocietyQuota(
    period: 'daily',
    freeBwPages: 5,
    freeColorPages: 0,
  );

  factory SocietyQuota.fromJson(Map<String, dynamic> json) {
    final period = json['period']?.toString();
    return SocietyQuota(
      period: period == 'weekly' || period == 'monthly' ? period! : 'daily',
      freeBwPages: _pages(json['freeBwPages'], defaults.freeBwPages),
      freeColorPages: _pages(json['freeColorPages'], defaults.freeColorPages),
    );
  }

  Map<String, dynamic> toJson() => {
        'period': period,
        'freeBwPages': freeBwPages,
        'freeColorPages': freeColorPages,
      };

  @override
  bool operator ==(Object other) {
    return other is SocietyQuota &&
        other.period == period &&
        other.freeBwPages == freeBwPages &&
        other.freeColorPages == freeColorPages;
  }

  @override
  int get hashCode => Object.hash(period, freeBwPages, freeColorPages);
}

class SocietyPhone {
  const SocietyPhone({
    required this.id,
    required this.phone,
    required this.createdAt,
  });

  final String id;
  final String phone;
  final String createdAt;

  factory SocietyPhone.fromJson(Map<String, dynamic> json) {
    return SocietyPhone(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
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
  final phone = raw.trim();
  if (phone.length < 8 || phone.length > 20) {
    return 'Enter a phone number (8–20 characters).';
  }
  return null;
}

int _pages(Object? raw, int fallback) {
  if (raw is! num) return fallback;
  final value = raw.toInt();
  if (value < 0 || value > 500) return fallback;
  return value;
}
