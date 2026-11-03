enum AstrologyInsightLocale { en, hi }

extension AstrologyInsightLocaleX on AstrologyInsightLocale {
  String get apiValue => switch (this) {
        AstrologyInsightLocale.en => 'en',
        AstrologyInsightLocale.hi => 'hi',
      };

  String get label => switch (this) {
        AstrologyInsightLocale.en => 'EN',
        AstrologyInsightLocale.hi => 'हिं',
      };
}

class LocaleBullets {
  const LocaleBullets({required this.en, required this.hi});

  final List<String> en;
  final List<String> hi;

  bool get isEmpty => en.isEmpty && hi.isEmpty;

  List<String> forLocale(AstrologyInsightLocale locale) {
    return switch (locale) {
      AstrologyInsightLocale.en => en,
      AstrologyInsightLocale.hi => hi,
    };
  }

  factory LocaleBullets.fromJson(Map<String, dynamic>? json) {
    List<String> parseList(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
    }

    return LocaleBullets(
      en: parseList(json?['en']),
      hi: parseList(json?['hi']),
    );
  }
}

class KundaliInsights {
  const KundaliInsights({
    this.rasiD1,
    this.navamshaD9,
    this.dashamamshaD10,
  });

  final LocaleBullets? rasiD1;
  final LocaleBullets? navamshaD9;
  final LocaleBullets? dashamamshaD10;

  LocaleBullets? forChart(String key) {
    return switch (key) {
      'RasiD1' => rasiD1,
      'NavamshaD9' => navamshaD9,
      'DashamamshaD10' => dashamamshaD10,
      _ => null,
    };
  }

  factory KundaliInsights.fromJson(Map<String, dynamic>? json) {
    LocaleBullets? parse(String key) {
      final raw = json?[key];
      if (raw is! Map<String, dynamic>) return null;
      final bullets = LocaleBullets.fromJson(raw);
      return bullets.isEmpty ? null : bullets;
    }

    return KundaliInsights(
      rasiD1: parse('RasiD1'),
      navamshaD9: parse('NavamshaD9'),
      dashamamshaD10: parse('DashamamshaD10'),
    );
  }
}
