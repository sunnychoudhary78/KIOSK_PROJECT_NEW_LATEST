import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:skp_kiosk/features/astrology/application/palm_path.dart';
import 'package:skp_kiosk/features/astrology/application/palm_roi.dart';

Uint8List encodePalmPng(img.Image image) =>
    Uint8List.fromList(img.encodePng(image));

/// Soft-textured open palm that passes strict quality (realistic grain, not salt noise).
Uint8List texturedPalmPng({
  int size = 220,
  int seed = 7,
  double fillChance = 1.0,
}) {
  final rng = math.Random(seed);
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(18, 18, 22));
  final crop = PalmRoi.crop(size, size);
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
      if (fillChance < 1.0 && rng.nextDouble() > fillChance) {
        continue;
      }
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
  return encodePalmPng(image);
}
