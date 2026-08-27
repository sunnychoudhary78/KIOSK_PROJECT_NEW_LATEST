import 'dart:typed_data';

import 'package:image/image.dart' as img;

class PalmQualityResult {
  const PalmQualityResult({
    required this.ok,
    required this.message,
    this.brightness = 0,
    this.blur = 0,
    this.skinRatio = 0,
  });

  final bool ok;
  final String message;
  final double brightness;
  final double blur;
  final double skinRatio;
}

/// Local palm-photo quality gates (no ML). Operates on a center ROI that
/// matches the on-screen palm outline.
class PalmQualityChecker {
  const PalmQualityChecker();

  static const minBrightness = 55.0;
  static const maxBrightness = 210.0;
  static const minBlur = 18.0;
  static const minSkinRatio = 0.18;

  PalmQualityResult evaluate(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width < 16 || decoded.height < 16) {
      return const PalmQualityResult(
        ok: false,
        message: 'Could not read the photo. Try again.',
      );
    }

    final left = (decoded.width * 0.25).round();
    final top = (decoded.height * 0.18).round();
    final width = (decoded.width * 0.50).round().clamp(8, decoded.width - left);
    final height = (decoded.height * 0.64).round().clamp(8, decoded.height - top);
    final roi = img.copyCrop(decoded, x: left, y: top, width: width, height: height);

    var lumaSum = 0.0;
    var skin = 0;
    final gray = List<int>.filled(roi.width * roi.height, 0);
    var index = 0;
    for (final pixel in roi) {
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final y = 0.299 * r + 0.587 * g + 0.114 * b;
      lumaSum += y;
      gray[index++] = y.round();
      if (_isSkin(r, g, b)) {
        skin++;
      }
    }

    final count = roi.width * roi.height;
    final brightness = lumaSum / count;
    final skinRatio = skin / count;
    final blur = _laplacianVariance(gray, roi.width, roi.height);

    if (brightness < minBrightness) {
      return PalmQualityResult(
        ok: false,
        message: 'Too dark. Face your palm toward the light.',
        brightness: brightness,
        blur: blur,
        skinRatio: skinRatio,
      );
    }
    if (brightness > maxBrightness) {
      return PalmQualityResult(
        ok: false,
        message: 'Too bright. Move a little away from the light.',
        brightness: brightness,
        blur: blur,
        skinRatio: skinRatio,
      );
    }
    if (blur < minBlur) {
      return PalmQualityResult(
        ok: false,
        message: 'Hold still — the image is blurry.',
        brightness: brightness,
        blur: blur,
        skinRatio: skinRatio,
      );
    }
    if (skinRatio < minSkinRatio) {
      return PalmQualityResult(
        ok: false,
        message: 'Place your open palm inside the outline.',
        brightness: brightness,
        blur: blur,
        skinRatio: skinRatio,
      );
    }

    return PalmQualityResult(
      ok: true,
      message: 'Palm looks clear. Hold still…',
      brightness: brightness,
      blur: blur,
      skinRatio: skinRatio,
    );
  }

  static bool _isSkin(int r, int g, int b) {
    final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
    final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
    return cb >= 77 && cb <= 127 && cr >= 133 && cr <= 173;
  }

  static double _laplacianVariance(List<int> gray, int width, int height) {
    if (width < 3 || height < 3) {
      return 0;
    }
    var sum = 0.0;
    var sumSq = 0.0;
    var n = 0;
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final c = gray[y * width + x];
        final lap =
            gray[(y - 1) * width + x] +
            gray[(y + 1) * width + x] +
            gray[y * width + x - 1] +
            gray[y * width + x + 1] -
            4 * c;
        sum += lap;
        sumSq += lap * lap;
        n++;
      }
    }
    if (n == 0) {
      return 0;
    }
    final mean = sum / n;
    return (sumSq / n) - mean * mean;
  }
}
