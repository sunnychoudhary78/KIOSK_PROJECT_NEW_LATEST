import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:skp_kiosk/features/astrology/application/palm_jpeg.dart';
import 'package:skp_kiosk/features/astrology/application/palm_path.dart';
import 'package:skp_kiosk/features/astrology/application/palm_roi.dart';

class PalmQualityResult {
  const PalmQualityResult({
    required this.ok,
    required this.message,
    this.brightness = 0,
    this.blur = 0,
    this.skinRatio = 0,
    this.outsideSkinRatio = 0,
  });

  final bool ok;
  final String message;
  final double brightness;
  final double blur;
  final double skinRatio;
  final double outsideSkinRatio;
}

/// Local palm-photo quality gates (no ML). Scores skin inside the on-screen
/// palm silhouette versus the rest of the ROI so empty rooms and faces do not
/// auto-capture.
class PalmQualityChecker {
  const PalmQualityChecker();

  static const minBrightness = 45.0;
  static const maxBrightness = 225.0;
  static const minInsideSkinRatio = 0.40;
  static const manualMinInsideSkinRatio = 0.28;
  static const minSkinContrast = 0.18;
  static const manualMinSkinContrast = 0.12;
  static const analysisMaxWidth = 160;

  PalmQualityResult evaluate(Uint8List bytes, {bool strict = true}) {
    final decoded = decodePalmImage(bytes);
    if (decoded == null || decoded.width < 16 || decoded.height < 16) {
      return const PalmQualityResult(
        ok: false,
        message: 'Could not read the photo. Try again.',
      );
    }

    final crop = PalmRoi.crop(decoded.width, decoded.height);
    var roi = img.copyCrop(
      decoded,
      x: crop.left,
      y: crop.top,
      width: crop.width,
      height: crop.height,
    );
    roi = _forAnalysis(roi);

    final palm = openPalmPath(
      Rect.fromLTWH(0, 0, roi.width.toDouble(), roi.height.toDouble()),
    );

    var lumaSum = 0.0;
    var lumaCount = 0;
    var insideSkin = 0;
    var insideCount = 0;
    var outsideSkin = 0;
    var outsideCount = 0;
    final gray = List<int>.filled(roi.width * roi.height, 0);
    var index = 0;

    for (var y = 0; y < roi.height; y++) {
      for (var x = 0; x < roi.width; x++) {
        final pixel = roi.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final yLuma = 0.299 * r + 0.587 * g + 0.114 * b;
        gray[index++] = yLuma.round();
        final skin = _isSkin(r, g, b);
        final inPalm = palm.contains(Offset(x + 0.5, y + 0.5));
        if (inPalm) {
          insideCount++;
          lumaSum += yLuma;
          lumaCount++;
          if (skin) {
            insideSkin++;
          }
        } else {
          outsideCount++;
          if (skin) {
            outsideSkin++;
          }
        }
      }
    }

    final brightness = lumaCount == 0 ? 0.0 : lumaSum / lumaCount;
    final insideSkinRatio = insideCount == 0 ? 0.0 : insideSkin / insideCount;
    final outsideSkinRatio = outsideCount == 0 ? 0.0 : outsideSkin / outsideCount;
    final blur = _laplacianVariance(gray, roi.width, roi.height);
    final skinMin = strict ? minInsideSkinRatio : manualMinInsideSkinRatio;
    final contrastMin = strict ? minSkinContrast : manualMinSkinContrast;

    if (brightness < minBrightness) {
      return PalmQualityResult(
        ok: false,
        message: 'Too dark. Face your palm toward the light.',
        brightness: brightness,
        blur: blur,
        skinRatio: insideSkinRatio,
        outsideSkinRatio: outsideSkinRatio,
      );
    }
    if (brightness > maxBrightness) {
      return PalmQualityResult(
        ok: false,
        message: 'Too bright. Move a little away from the light.',
        brightness: brightness,
        blur: blur,
        skinRatio: insideSkinRatio,
        outsideSkinRatio: outsideSkinRatio,
      );
    }
    if (insideSkinRatio < skinMin || insideSkinRatio - outsideSkinRatio < contrastMin) {
      return PalmQualityResult(
        ok: false,
        message: 'Place your open palm inside the outline.',
        brightness: brightness,
        blur: blur,
        skinRatio: insideSkinRatio,
        outsideSkinRatio: outsideSkinRatio,
      );
    }

    return PalmQualityResult(
      ok: true,
      message: 'Palm looks clear. Hold still…',
      brightness: brightness,
      blur: blur,
      skinRatio: insideSkinRatio,
      outsideSkinRatio: outsideSkinRatio,
    );
  }

  static img.Image _forAnalysis(img.Image roi) {
    if (roi.width <= analysisMaxWidth) {
      return roi;
    }
    final height = math.max(8, (roi.height * (analysisMaxWidth / roi.width)).round());
    return img.copyResize(roi, width: analysisMaxWidth, height: height);
  }

  static bool _isSkin(int r, int g, int b) {
    return _isYcbCrSkin(r, g, b) || _isRgbSkin(r, g, b);
  }

  static bool _isYcbCrSkin(int r, int g, int b) {
    final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
    final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
    return cb >= 70 && cb <= 135 && cr >= 133 && cr <= 180;
  }

  /// Kovac RGB — real palms, not beige walls (no warm-tint shortcut).
  static bool _isRgbSkin(int r, int g, int b) {
    final maxc = math.max(r, math.max(g, b));
    final minc = math.min(r, math.min(g, b));
    return r > 95 &&
        g > 40 &&
        b > 20 &&
        r > g &&
        r > b &&
        (r - g) > 15 &&
        (maxc - minc) > 15;
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
