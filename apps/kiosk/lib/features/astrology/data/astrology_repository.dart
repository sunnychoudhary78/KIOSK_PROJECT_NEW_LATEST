import 'dart:typed_data';

import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_result.dart';

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
}
