import 'dart:typed_data';

import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_result.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_result.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_result.dart';

class AstrologySubmitInput {
  const AstrologySubmitInput({
    required this.name,
    required this.gender,
    required this.dateOfBirth,
    required this.birthTime,
    required this.birthPlace,
    required this.birthTimeUnknown,
    required this.palmJpeg,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String gender;
  final String dateOfBirth;
  final String birthTime;
  final String birthPlace;
  final bool birthTimeUnknown;
  final Uint8List palmJpeg;
  final double? latitude;
  final double? longitude;
}

class KundaliSubmitInput {
  const KundaliSubmitInput({
    required this.name,
    required this.gender,
    required this.dateOfBirth,
    required this.birthTime,
    required this.birthPlace,
    required this.birthTimeUnknown,
    required this.style,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String gender;
  final String dateOfBirth;
  final String birthTime;
  final String birthPlace;
  final bool birthTimeUnknown;
  final String style;
  final double? latitude;
  final double? longitude;
}

class MatchPersonInput {
  const MatchPersonInput({
    required this.name,
    required this.dateOfBirth,
    required this.birthTime,
    required this.birthPlace,
    required this.birthTimeUnknown,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String dateOfBirth;
  final String birthTime;
  final String birthPlace;
  final bool birthTimeUnknown;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
    'name': name,
    'dateOfBirth': dateOfBirth,
    'birthTime': birthTime,
    'birthPlace': birthPlace,
    'birthTimeUnknown': birthTimeUnknown,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}

class TodaySubmitInput {
  const TodaySubmitInput({
    required this.name,
    required this.gender,
    required this.dateOfBirth,
    required this.birthTime,
    required this.birthPlace,
    required this.birthTimeUnknown,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String gender;
  final String dateOfBirth;
  final String birthTime;
  final String birthPlace;
  final bool birthTimeUnknown;
  final double? latitude;
  final double? longitude;
}

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.label,
    required this.subtitle,
  });

  final String id;
  final String label;
  final String subtitle;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
    );
  }
}

class ResolvedBirthPlace {
  const ResolvedBirthPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;

  factory ResolvedBirthPlace.fromJson(Map<String, dynamic> json) {
    return ResolvedBirthPlace(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AstrologyRepository {
  AstrologyRepository(this._api);

  final ApiClient _api;

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final result = await _api.get(
      '/astrology/places?q=${Uri.encodeQueryComponent(query)}',
    );
    final raw = result['suggestions'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PlaceSuggestion.fromJson)
        .toList();
  }

  Future<ResolvedBirthPlace> resolvePlace(String id) async {
    final result = await _api.get(
      '/astrology/places/${Uri.encodeComponent(id)}',
    );
    return ResolvedBirthPlace.fromJson(result);
  }

  Future<AstrologyReading> createReading(AstrologySubmitInput input) async {
    final result = await _api.postMultipart(
      '/astrology/readings',
      fields: {
        'name': input.name,
        'gender': input.gender,
        'dateOfBirth': input.dateOfBirth,
        'birthTime': input.birthTime,
        'birthPlace': input.birthPlace,
        'birthTimeUnknown': input.birthTimeUnknown ? 'true' : 'false',
        if (input.latitude != null) 'latitude': '${input.latitude}',
        if (input.longitude != null) 'longitude': '${input.longitude}',
      },
      fileBytes: input.palmJpeg,
      fileField: 'palm',
      filename: 'palm.jpg',
      contentType: 'image/jpeg',
    );
    return AstrologyReading.fromJson(result);
  }

  Future<KundaliResult> createKundali(KundaliSubmitInput input) async {
    final result = await _api.post(
      '/astrology/kundali',
      body: {
        'name': input.name,
        'gender': input.gender,
        'dateOfBirth': input.dateOfBirth,
        'birthTime': input.birthTime,
        'birthPlace': input.birthPlace,
        'birthTimeUnknown': input.birthTimeUnknown,
        'style': input.style,
        'chartType': 'RasiD1',
        if (input.latitude != null) 'latitude': input.latitude,
        if (input.longitude != null) 'longitude': input.longitude,
      },
    );
    return KundaliResult.fromJson(result);
  }

  Future<MatchKundaliResult> createMatch({
    required MatchPersonInput groom,
    required MatchPersonInput bride,
  }) async {
    final result = await _api.post(
      '/astrology/match',
      body: {'groom': groom.toJson(), 'bride': bride.toJson()},
    );
    return MatchKundaliResult.fromJson(result);
  }

  Future<TodayPeriodsResult> createToday(TodaySubmitInput input) async {
    final result = await _api.post(
      '/astrology/today',
      body: {
        'name': input.name,
        'gender': input.gender,
        'dateOfBirth': input.dateOfBirth,
        'birthTime': input.birthTime,
        'birthPlace': input.birthPlace,
        'birthTimeUnknown': input.birthTimeUnknown,
        if (input.latitude != null) 'latitude': input.latitude,
        if (input.longitude != null) 'longitude': input.longitude,
      },
    );
    return TodayPeriodsResult.fromJson(result);
  }
}
