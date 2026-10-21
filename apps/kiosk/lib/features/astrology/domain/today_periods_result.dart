class TodayPanchang {
  const TodayPanchang({
    this.weekday,
    this.tithi,
    this.nakshatra,
    this.yoga,
    this.karana,
    this.lunarMonth,
    this.sunrise,
    this.sunset,
    this.horaLord,
    this.dishaShool,
  });

  final String? weekday;
  final String? tithi;
  final String? nakshatra;
  final String? yoga;
  final String? karana;
  final String? lunarMonth;
  final String? sunrise;
  final String? sunset;
  final String? horaLord;
  final String? dishaShool;

  factory TodayPanchang.fromJson(Map<String, dynamic>? json) {
    return TodayPanchang(
      weekday: json?['weekday']?.toString(),
      tithi: json?['tithi']?.toString(),
      nakshatra: json?['nakshatra']?.toString(),
      yoga: json?['yoga']?.toString(),
      karana: json?['karana']?.toString(),
      lunarMonth: json?['lunarMonth']?.toString(),
      sunrise: json?['sunrise']?.toString(),
      sunset: json?['sunset']?.toString(),
      horaLord: json?['horaLord']?.toString(),
      dishaShool: json?['dishaShool']?.toString(),
    );
  }

  List<({String label, String value})> get rows {
    return [
      if (weekday != null && weekday!.trim().isNotEmpty)
        (label: 'Weekday', value: weekday!),
      if (tithi != null && tithi!.trim().isNotEmpty)
        (label: 'Tithi', value: tithi!),
      if (nakshatra != null && nakshatra!.trim().isNotEmpty)
        (label: 'Nakshatra', value: nakshatra!),
      if (yoga != null && yoga!.trim().isNotEmpty) (label: 'Yoga', value: yoga!),
      if (karana != null && karana!.trim().isNotEmpty)
        (label: 'Karana', value: karana!),
      if (lunarMonth != null && lunarMonth!.trim().isNotEmpty)
        (label: 'Lunar month', value: lunarMonth!),
      if (sunrise != null && sunrise!.trim().isNotEmpty)
        (label: 'Sunrise', value: sunrise!),
      if (sunset != null && sunset!.trim().isNotEmpty)
        (label: 'Sunset', value: sunset!),
      if (horaLord != null && horaLord!.trim().isNotEmpty)
        (label: 'Hora lord', value: horaLord!),
      if (dishaShool != null && dishaShool!.trim().isNotEmpty)
        (label: 'Disha shool', value: dishaShool!),
    ];
  }
}

class TodayDasha {
  const TodayDasha({required this.label, required this.levels});

  final String label;
  final List<String> levels;

  factory TodayDasha.fromJson(Map<String, dynamic>? json) {
    final rawLevels = json?['levels'] as List<dynamic>? ?? const [];
    return TodayDasha(
      label: json?['label']?.toString() ?? '',
      levels: rawLevels.map((entry) => entry.toString()).toList(),
    );
  }
}

class TodayPeriodsResult {
  const TodayPeriodsResult({
    required this.disclaimer,
    required this.name,
    required this.asOf,
    required this.panchang,
    required this.dasha,
    this.accuracyNote,
  });

  final String disclaimer;
  final String? accuracyNote;
  final String name;
  final DateTime? asOf;
  final TodayPanchang panchang;
  final TodayDasha dasha;

  factory TodayPeriodsResult.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] as Map<String, dynamic>? ?? const {};
    final asOfRaw = json['asOf']?.toString();
    return TodayPeriodsResult(
      disclaimer:
          json['disclaimer']?.toString() ??
          'For entertainment only. Not medical, legal, or financial advice.',
      accuracyNote: json['accuracyNote']?.toString(),
      name: subject['name']?.toString() ?? 'Guest',
      asOf: asOfRaw == null ? null : DateTime.tryParse(asOfRaw),
      panchang: TodayPanchang.fromJson(
        json['panchang'] as Map<String, dynamic>?,
      ),
      dasha: TodayDasha.fromJson(json['dasha'] as Map<String, dynamic>?),
    );
  }
}
