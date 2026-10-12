import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/fuel_stations/domain/polyline_codec.dart';

void main() {
  group('decodePolyline', () {
    test('returns empty for blank input', () {
      expect(decodePolyline(''), isEmpty);
    });

    test('decodes a known Google encoded sample', () {
      // Encodes (38.5, -120.2), (40.7, -120.95), (43.252, -126.453)
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final points = decodePolyline(encoded);
      expect(points, hasLength(3));
      expect(points[0].lat, closeTo(38.5, 0.0001));
      expect(points[0].lng, closeTo(-120.2, 0.0001));
      expect(points[1].lat, closeTo(40.7, 0.0001));
      expect(points[1].lng, closeTo(-120.95, 0.0001));
      expect(points[2].lat, closeTo(43.252, 0.0001));
      expect(points[2].lng, closeTo(-126.453, 0.0001));
    });
  });
}
