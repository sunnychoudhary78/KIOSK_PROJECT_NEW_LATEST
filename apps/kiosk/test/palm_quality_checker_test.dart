import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:skp_kiosk/features/astrology/application/palm_path.dart';
import 'package:skp_kiosk/features/astrology/application/palm_quality_checker.dart';
import 'package:skp_kiosk/features/astrology/application/palm_roi.dart';

import 'palm_quality_fixtures.dart';

void main() {
  const checker = PalmQualityChecker();

  test('synthetic filled open palm passes strict', () {
    final result = checker.evaluate(texturedPalmPng());
    expect(result.ok, isTrue, reason: result.message);
    expect(result.centroidOk, isTrue);
    expect(
      result.skinRatio,
      greaterThanOrEqualTo(PalmQualityChecker.minInsideSkinRatio),
    );
  });

  test('blank frame fails', () {
    final blank = img.Image(width: 120, height: 120);
    img.fill(blank, color: img.ColorRgb8(10, 10, 10));
    final result = checker.evaluate(encodePalmPng(blank));
    expect(result.ok, isFalse);
  });

  test('uniform beige wall fails', () {
    final wall = img.Image(width: 160, height: 160);
    img.fill(wall, color: img.ColorRgb8(210, 190, 160));
    final result = checker.evaluate(encodePalmPng(wall));
    expect(result.ok, isFalse);
  });

  test('face-like full-frame skin fails coverage / outside gates', () {
    final face = img.Image(width: 160, height: 160);
    final rng = math.Random(2);
    for (var y = 0; y < face.height; y++) {
      for (var x = 0; x < face.width; x++) {
        final wave = (math.sin(x * 0.3) * 6).round();
        final n = rng.nextInt(5) - 2 + wave;
        face.setPixelRgb(
          x,
          y,
          (185 + n).clamp(100, 240),
          (120 + n ~/ 2).clamp(50, 200),
          (80 + n ~/ 3).clamp(30, 160),
        );
      }
    }
    final result = checker.evaluate(encodePalmPng(face));
    expect(result.ok, isFalse);
    expect(
      result.outsideSkinRatio > PalmQualityChecker.maxOutsideSkinRatio ||
          result.roiSkinRatio > PalmQualityChecker.maxRoiSkinRatio,
      isTrue,
    );
  });

  test('manual gate accepts a slightly thinner palm fill', () {
    // Contiguous inset palm (~0.46 of full silhouette area) with soft texture.
    final rng = math.Random(5);
    const size = 220;
    final image = img.Image(width: size, height: size);
    img.fill(image, color: img.ColorRgb8(18, 18, 22));
    final crop = PalmRoi.crop(size, size);
    final bounds = Rect.fromLTWH(
      crop.left.toDouble(),
      crop.top.toDouble(),
      crop.width.toDouble(),
      crop.height.toDouble(),
    );
    final fullPalm = openPalmPath(bounds);
    final insetBounds = Rect.fromCenter(
      center: bounds.center,
      width: bounds.width * 0.70,
      height: bounds.height * 0.70,
    );
    final insetPalm = openPalmPath(insetBounds);

    var total = 0;
    var filled = 0;
    for (var y = crop.top; y < crop.top + crop.height; y++) {
      for (var x = crop.left; x < crop.left + crop.width; x++) {
        final pt = Offset(x + 0.5, y + 0.5);
        if (!fullPalm.contains(pt)) {
          continue;
        }
        total++;
        if (!insetPalm.contains(pt)) {
          continue;
        }
        filled++;
        final wave = (math.sin(x * 0.35) * 8 + math.cos(y * 0.28) * 8).round();
        final grain = rng.nextInt(7) - 3;
        final n = wave + grain;
        image.setPixelRgb(
          x,
          y,
          (176 + n).clamp(96, 240),
          (112 + n ~/ 2).clamp(45, 200),
          (74 + n ~/ 3).clamp(25, 160),
        );
      }
    }
    expect(filled / total, greaterThan(0.42));
    expect(filled / total, lessThan(0.52));

    final bytes = encodePalmPng(image);
    final strict = checker.evaluate(bytes, strict: true);
    final manual = checker.evaluate(bytes, strict: false);
    expect(strict.ok, isFalse, reason: strict.message);
    expect(manual.ok, isTrue, reason: manual.message);
  });
}
