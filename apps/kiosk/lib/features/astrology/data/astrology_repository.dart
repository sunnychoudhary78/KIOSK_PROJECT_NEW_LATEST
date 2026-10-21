import 'dart:typed_data';

import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_result.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_result.dart';

class AstrologySubmitInput {
  const AstrologySubmitInput({
    required this.name,
    required this.gender,
    required this.dateOfBirth,
    required this.birthTime,
    required this.birthPlace,
    required this.birthTimeUnknown,
    required this.palmJpeg,
  });

  final String name;
  final String gender;
  final String dateOfBirth;
  final String birthTime;
  final String birthPlace;
  final bool birthTimeUnknown;
  final Uint8List palmJpeg;
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
  });

  final String name;
  final String gender;
  final String dateOfBirth;
  final String birthTime;
  final String birthPlace;
  final bool birthTimeUnknown;
  final String style;
}

class MatchPersonInput {
  const MatchPersonInput({
    required this.name,
    required this.dateOfBirth,
    required this.birthTime,
    required this.birthPlace,
    required this.birthTimeUnknown,
  });

  final String name;
  final String dateOfBirth;
  final String birthTime;
  final String birthPlace;
  final bool birthTimeUnknown;

  Map<String, dynamic> toJson() => {
    'name': name,
    'dateOfBirth': dateOfBirth,
    'birthTime': birthTime,
    'birthPlace': birthPlace,
    'birthTimeUnknown': birthTimeUnknown,
  };
}

class AstrologyRepository {
  AstrologyRepository(this._api);

  final ApiClient _api;

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
}
