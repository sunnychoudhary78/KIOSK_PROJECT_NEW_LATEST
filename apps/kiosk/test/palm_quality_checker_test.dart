import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:skp_kiosk/features/astrology/application/palm_path.dart';
import 'package:skp_kiosk/features/astrology/application/palm_quality_checker.dart';
import 'package:skp_kiosk/features/astrology/application/palm_roi.dart';

Uint8List _png(img.Image image) {
  return Uint8List.fromList(img.encodePng(image));
}

void _paintPalm(
  img.Image image, {
  required int r,
  required int g,
  required int b,
  bool Function(int x, int y)? keep,
}) {
  final crop = PalmRoi.crop(image.width, image.height);
  final palm = openPalmPath(
    Rect.fromLTWH(
      crop.left.toDouble(),
      crop.top.toDouble(),
      crop.width.toDouble(),
      crop.height.toDouble(),
    ),
  );
  for (var y = crop.top; y < crop.top + crop.height; y++) {
    for (var x = crop.left; x < crop.left + crop.width; x++) {
      if (!palm.contains(Offset(x + 0.5, y + 0.5))) {
        continue;
      }
      if (keep != null && !keep(x, y)) {
        continue;
      }
      image.setPixelRgb(x, y, r, g, b);
    }
  }
}

Uint8List _palmPng({
  int size = 160,
  int r = 180,
  int g = 120,
  int b = 80,
}) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(20, 20, 20));
  _paintPalm(image, r: r, g: g, b: b);
  return _png(image);
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

  test('rejects a beige wood-colored scene with no hand', () {
    final image = img.Image(width: 160, height: 160);
    img.fill(image, color: img.ColorRgb8(194, 154, 107));
    final result = checker.evaluate(_png(image));
    expect(result.ok, isFalse);
    expect(result.message.toLowerCase(), contains('palm'));
  });

  test('rejects skin filling the entire frame like a face or body', () {
    final image = img.Image(width: 160, height: 160);
    img.fill(image, color: img.ColorRgb8(180, 120, 80));
    final result = checker.evaluate(_png(image));
    expect(result.ok, isFalse);
    expect(result.message.toLowerCase(), contains('palm'));
  });

  test('accepts a palm painted only inside the outline', () {
    final result = checker.evaluate(_palmPng());
    expect(result.ok, isTrue, reason: result.message);
  });

  test('accepts a darker brown palm in the outline', () {
    final result = checker.evaluate(_palmPng(r: 110, g: 75, b: 50));
    expect(result.ok, isTrue, reason: result.message);
  });

  test('accepts a yellowish white-balance palm in the outline', () {
    final result = checker.evaluate(_palmPng(r: 160, g: 148, b: 70));
    expect(result.ok, isTrue, reason: result.message);
  });

  test('rejects a palm that sits outside the outline', () {
    final image = img.Image(width: 160, height: 160);
    img.fill(image, color: img.ColorRgb8(20, 20, 20));
    for (var y = 0; y < 20; y++) {
      for (var x = 0; x < 20; x++) {
        image.setPixelRgb(x, y, 180, 120, 80);
      }
    }
    final result = checker.evaluate(_png(image));
    expect(result.ok, isFalse);
    expect(result.message.toLowerCase(), contains('palm'));
  });

  test('manual capture accepts a thinner palm fill that auto-capture rejects', () {
    final image = img.Image(width: 160, height: 160);
    img.fill(image, color: img.ColorRgb8(20, 20, 20));
    final crop = PalmRoi.crop(160, 160);
    final split = crop.top + (crop.height * 0.58).round();
    _paintPalm(
      image,
      r: 180,
      g: 120,
      b: 80,
      keep: (x, y) => y >= split,
    );
    final auto = checker.evaluate(_png(image));
    final manual = checker.evaluate(_png(image), strict: false);
    expect(auto.ok, isFalse);
    expect(manual.ok, isTrue, reason: manual.message);
  });
}
