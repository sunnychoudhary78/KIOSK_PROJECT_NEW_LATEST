import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:skp_kiosk/features/astrology/application/palm_quality_checker.dart';

Uint8List _png(img.Image image) {
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  const checker = PalmQualityChecker();

  test('rejects a dark frame', () {
    final image = img.Image(width: 96, height: 96);
    img.fill(image, color: img.ColorRgb8(8, 8, 8));
    final result = checker.evaluate(_png(image));
    expect(result.ok, isFalse);
    expect(result.message, contains('dark'));
  });

  test('rejects a blown-out frame', () {
    final image = img.Image(width: 96, height: 96);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final result = checker.evaluate(_png(image));
    expect(result.ok, isFalse);
    expect(result.message, contains('bright'));
  });

  test('rejects a gray frame with no palm-colored pixels', () {
    final image = img.Image(width: 96, height: 96);
    img.fill(image, color: img.ColorRgb8(120, 120, 120));
    for (var y = 0; y < image.height; y += 2) {
      for (var x = 0; x < image.width; x += 2) {
        image.setPixelRgb(x, y, 40, 40, 40);
      }
    }
    final result = checker.evaluate(_png(image));
    expect(result.ok, isFalse);
    expect(result.message.toLowerCase(), contains('palm'));
  });

  test('accepts a high-contrast skin-toned palm in the outline', () {
    final image = img.Image(width: 160, height: 160);
    img.fill(image, color: img.ColorRgb8(20, 20, 20));
    for (var y = 28; y < 132; y++) {
      for (var x = 40; x < 120; x++) {
        final contrast = ((x + y) % 6 == 0) ? 40 : 0;
        image.setPixelRgb(x, y, 210 - contrast, 160 - contrast, 120 - contrast);
      }
    }
    final result = checker.evaluate(_png(image));
    expect(result.ok, isTrue, reason: result.message);
  });
}
