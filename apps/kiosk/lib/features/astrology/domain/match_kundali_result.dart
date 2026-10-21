const matchKutaSpecs = [
  ('varna', 'Varna', 1.0),
  ('vasya', 'Vasya', 2.0),
  ('dina', 'Dina (Tara)', 3.0),
  ('yoni', 'Yoni', 4.0),
  ('graha-maitri', 'Graha Maitri', 5.0),
  ('gana', 'Gana', 6.0),
  ('rasi', 'Rasi (Bhakoot)', 7.0),
  ('nadi', 'Nadi', 8.0),
];

List<MatchKuta> padMatchKutas(List<MatchKuta> kutas) {
  return [
    for (var i = 0; i < matchKutaSpecs.length; i++)
      i < kutas.length
          ? kutas[i]
          : MatchKuta(
              key: matchKutaSpecs[i].$1,
              name: matchKutaSpecs[i].$2,
              maxPoints: matchKutaSpecs[i].$3,
              nature: 'Neutral',
              verdict: 'No detailed note returned.',
            ),
  ];
}

class MatchKuta {
  const MatchKuta({
    required this.key,
    required this.name,
    required this.maxPoints,
    required this.nature,
    required this.verdict,
    this.points,
  });

  final String key;
  final String name;
  final double maxPoints;
  final double? points;
  final String nature;
  final String verdict;

  factory MatchKuta.fromJson(Map<String, dynamic> json) {
    return MatchKuta(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      maxPoints: (json['maxPoints'] as num?)?.toDouble() ?? 0,
      points: (json['points'] as num?)?.toDouble(),
      nature: json['nature']?.toString() ?? 'Neutral',
      verdict: json['verdict']?.toString() ?? '',
    );
  }
}

class MatchScore {
  const MatchScore({
    required this.total,
    required this.max,
    required this.summary,
    required this.tone,
  });

  final double total;
  final double max;
  final String summary;
  final String tone;

  factory MatchScore.fromJson(Map<String, dynamic>? json) {
    return MatchScore(
      total: (json?['total'] as num?)?.toDouble() ?? 0,
      max: (json?['max'] as num?)?.toDouble() ?? 36,
      summary: json?['summary']?.toString() ?? 'Compatibility report',
      tone: json?['tone']?.toString() ?? 'mixed',
    );
  }
}

class MatchKundaliResult {
  const MatchKundaliResult({
    required this.disclaimer,
    required this.groomName,
    required this.brideName,
    required this.score,
    required this.kutas,
    this.accuracyNote,
  });

  final String disclaimer;
  final String? accuracyNote;
  final String groomName;
  final String brideName;
  final MatchScore score;
  final List<MatchKuta> kutas;

  factory MatchKundaliResult.fromJson(Map<String, dynamic> json) {
    final groom = json['groom'] as Map<String, dynamic>? ?? const {};
    final bride = json['bride'] as Map<String, dynamic>? ?? const {};
    final rawKutas = json['kutas'] as List<dynamic>? ?? const [];
    return MatchKundaliResult(
      disclaimer:
          json['disclaimer']?.toString() ??
          'For entertainment only. Not medical, legal, or financial advice.',
      accuracyNote: json['accuracyNote']?.toString(),
      groomName: groom['name']?.toString() ?? 'Groom',
      brideName: bride['name']?.toString() ?? 'Bride',
      score: MatchScore.fromJson(json['score'] as Map<String, dynamic>?),
      kutas: padMatchKutas(
        rawKutas
            .whereType<Map<String, dynamic>>()
            .map(MatchKuta.fromJson)
            .toList(),
      ),
    );
  }
}
