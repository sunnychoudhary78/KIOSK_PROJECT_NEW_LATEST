class AstrologyPalmInsight {
  const AstrologyPalmInsight({
    required this.summary,
    required this.lifeLine,
    required this.heartLine,
    required this.headLine,
    required this.fateLine,
  });

  final String summary;
  final String lifeLine;
  final String heartLine;
  final String headLine;
  final String fateLine;

  factory AstrologyPalmInsight.fromJson(Map<String, dynamic> json) {
    return AstrologyPalmInsight(
      summary: json['summary']?.toString() ?? '',
      lifeLine: json['lifeLine']?.toString() ?? '',
      heartLine: json['heartLine']?.toString() ?? '',
      headLine: json['headLine']?.toString() ?? '',
      fateLine: json['fateLine']?.toString() ?? '',
    );
  }
}

class AstrologyReadingSections {
  const AstrologyReadingSections({
    required this.overview,
    required this.personality,
    required this.career,
    required this.health,
    required this.relationships,
    required this.period,
  });

  final String overview;
  final String personality;
  final String career;
  final String health;
  final String relationships;
  final String period;

  factory AstrologyReadingSections.fromJson(Map<String, dynamic> json) {
    return AstrologyReadingSections(
      overview: json['overview']?.toString() ?? '',
      personality: json['personality']?.toString() ?? '',
      career: json['career']?.toString() ?? '',
      health: json['health']?.toString() ?? '',
      relationships: json['relationships']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
    );
  }
}

class AstrologyChartSummary {
  const AstrologyChartSummary({
    this.lagna,
    this.sunSign,
    this.moonSign,
    this.nakshatra,
    this.currentDasha,
  });

  final String? lagna;
  final String? sunSign;
  final String? moonSign;
  final String? nakshatra;
  final String? currentDasha;

  factory AstrologyChartSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const AstrologyChartSummary();
    }
    return AstrologyChartSummary(
      lagna: json['lagna']?.toString(),
      sunSign: json['sunSign']?.toString(),
      moonSign: json['moonSign']?.toString(),
      nakshatra: json['nakshatra']?.toString(),
      currentDasha: json['currentDasha']?.toString(),
    );
  }
}

class AstrologyReading {
  const AstrologyReading({
    required this.id,
    required this.disclaimer,
    required this.name,
    required this.chart,
    required this.palm,
    required this.sections,
  });

  final String id;
  final String disclaimer;
  final String name;
  final AstrologyChartSummary chart;
  final AstrologyPalmInsight palm;
  final AstrologyReadingSections sections;

  factory AstrologyReading.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] as Map<String, dynamic>? ?? const {};
    return AstrologyReading(
      id: json['id']?.toString() ?? '',
      disclaimer: json['disclaimer']?.toString() ??
          'For entertainment only. Not medical, legal, or financial advice.',
      name: subject['name']?.toString() ?? '',
      chart: AstrologyChartSummary.fromJson(json['chart'] as Map<String, dynamic>?),
      palm: AstrologyPalmInsight.fromJson(
        json['palm'] as Map<String, dynamic>? ?? const {},
      ),
      sections: AstrologyReadingSections.fromJson(
        json['reading'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}
