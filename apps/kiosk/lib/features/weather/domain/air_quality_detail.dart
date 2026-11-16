class AirQualityColor {
  const AirQualityColor({required this.r, required this.g, required this.b});

  final int r;
  final int g;
  final int b;

  factory AirQualityColor.fromJson(Map<String, dynamic> json) {
    return AirQualityColor(
      r: _asInt(json['r']) ?? 0,
      g: _asInt(json['g']) ?? 0,
      b: _asInt(json['b']) ?? 0,
    );
  }
}

class AirQualityConcentration {
  const AirQualityConcentration({required this.value, required this.units});

  final double value;
  final String units;

  factory AirQualityConcentration.fromJson(Map<String, dynamic> json) {
    return AirQualityConcentration(
      value: _asDouble(json['value']) ?? 0,
      units: (json['units'] as String?)?.trim() ?? '',
    );
  }
}

class AirQualityPollutant {
  const AirQualityPollutant({
    required this.code,
    required this.displayName,
    this.concentration,
  });

  final String code;
  final String displayName;
  final AirQualityConcentration? concentration;

  factory AirQualityPollutant.fromJson(Map<String, dynamic> json) {
    final rawConcentration = json['concentration'];
    return AirQualityPollutant(
      code: (json['code'] as String?)?.trim() ?? '',
      displayName: (json['displayName'] as String?)?.trim() ?? '',
      concentration: rawConcentration is Map<String, dynamic>
          ? AirQualityConcentration.fromJson(rawConcentration)
          : null,
    );
  }
}

class AirQualityHealthRecommendations {
  const AirQualityHealthRecommendations({
    this.generalPopulation,
    this.elderly,
    this.lungDiseasePopulation,
    this.heartDiseasePopulation,
    this.athletes,
    this.pregnantWomen,
    this.children,
  });

  final String? generalPopulation;
  final String? elderly;
  final String? lungDiseasePopulation;
  final String? heartDiseasePopulation;
  final String? athletes;
  final String? pregnantWomen;
  final String? children;

  factory AirQualityHealthRecommendations.fromJson(Map<String, dynamic> json) {
    return AirQualityHealthRecommendations(
      generalPopulation: json['generalPopulation'] as String?,
      elderly: json['elderly'] as String?,
      lungDiseasePopulation: json['lungDiseasePopulation'] as String?,
      heartDiseasePopulation: json['heartDiseasePopulation'] as String?,
      athletes: json['athletes'] as String?,
      pregnantWomen: json['pregnantWomen'] as String?,
      children: json['children'] as String?,
    );
  }

  List<(String, String)> get sensitiveGroups {
    final groups = <(String, String)>[];
    void add(String label, String? text) {
      final value = text?.trim();
      if (value != null && value.isNotEmpty) {
        groups.add((label, value));
      }
    }

    add('Elderly', elderly);
    add('Lung conditions', lungDiseasePopulation);
    add('Heart conditions', heartDiseasePopulation);
    add('Athletes', athletes);
    add('Pregnant women', pregnantWomen);
    add('Children', children);
    return groups;
  }
}

class AirQualityDetail {
  const AirQualityDetail({
    this.aqi,
    this.aqiLabel,
    this.dominantPollutant,
    this.color,
    this.pollutants = const [],
    this.healthRecommendations,
    this.updatedAt,
  });

  final int? aqi;
  final String? aqiLabel;
  final String? dominantPollutant;
  final AirQualityColor? color;
  final List<AirQualityPollutant> pollutants;
  final AirQualityHealthRecommendations? healthRecommendations;
  final String? updatedAt;

  bool get hasDisplayableData =>
      aqi != null || pollutants.isNotEmpty || healthRecommendations != null;

  AirQualityPollutant? pollutantByCode(String code) {
    final needle = code.trim().toLowerCase();
    for (final pollutant in pollutants) {
      if (pollutant.code.toLowerCase() == needle) {
        return pollutant;
      }
    }
    return null;
  }

  factory AirQualityDetail.fromJson(Map<String, dynamic> json) {
    final rawColor = json['color'];
    final rawHealth = json['healthRecommendations'];
    final rawPollutants = json['pollutants'];
    return AirQualityDetail(
      aqi: _asInt(json['aqi']),
      aqiLabel: json['aqiLabel'] as String?,
      dominantPollutant: json['dominantPollutant'] as String?,
      color: rawColor is Map<String, dynamic>
          ? AirQualityColor.fromJson(rawColor)
          : null,
      pollutants: rawPollutants is List
          ? rawPollutants
              .whereType<Map>()
              .map(
                (item) => AirQualityPollutant.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
      healthRecommendations: rawHealth is Map<String, dynamic>
          ? AirQualityHealthRecommendations.fromJson(rawHealth)
          : null,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class AirQualityHistoryPoint {
  const AirQualityHistoryPoint({
    required this.dateTime,
    this.aqi,
    this.aqiLabel,
  });

  final String dateTime;
  final int? aqi;
  final String? aqiLabel;

  factory AirQualityHistoryPoint.fromJson(Map<String, dynamic> json) {
    return AirQualityHistoryPoint(
      dateTime: (json['dateTime'] as String?)?.trim() ?? '',
      aqi: _asInt(json['aqi']),
      aqiLabel: json['aqiLabel'] as String?,
    );
  }
}

class AirQualityHistory {
  const AirQualityHistory({this.points = const []});

  final List<AirQualityHistoryPoint> points;

  factory AirQualityHistory.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    return AirQualityHistory(
      points: rawPoints is List
          ? rawPoints
              .whereType<Map>()
              .map(
                (item) => AirQualityHistoryPoint.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((point) => point.dateTime.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

double? _asDouble(Object? raw) {
  if (raw is num) {
    return raw.toDouble();
  }
  if (raw is String) {
    return double.tryParse(raw);
  }
  return null;
}

int? _asInt(Object? raw) {
  if (raw is num) {
    return raw.round();
  }
  if (raw is String) {
    return int.tryParse(raw) ?? double.tryParse(raw)?.round();
  }
  return null;
}
