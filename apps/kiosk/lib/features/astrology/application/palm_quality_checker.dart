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
    this.roiSkinRatio = 0,
    this.fingerSkinRatio = 0,
    this.centroidOk = false,
  });

  final bool ok;
  final String message;
  final double brightness;
  final double blur;
  final double skinRatio;
  final double outsideSkinRatio;
  /// Skin pixels as a fraction of the full ROI (not only the palm path).
  final double roiSkinRatio;
  final double fingerSkinRatio;
  final bool centroidOk;
}

/// Local palm-photo quality gates (no ML). Scores skin inside the on-screen
/// palm silhouette versus the rest of the ROI so empty rooms and faces do not
/// auto-capture.
class PalmQualityChecker {
  const PalmQualityChecker();

  static const minBrightness = 50.0;
  static const maxBrightness = 215.0;

  static const minInsideSkinRatio = 0.46;
  static const manualMinInsideSkinRatio = 0.42;
  static const minSkinContrast = 0.24;
  static const manualMinSkinContrast = 0.20;

  static const maxOutsideSkinRatio = 0.26;
  static const manualMaxOutsideSkinRatio = 0.30;

  /// Reject “whole ROI is skin” (face close-up).
  static const maxRoiSkinRatio = 0.76;
  static const manualMaxRoiSkinRatio = 0.82;

  static const minBlur = 12.0;
  static const manualMinBlur = 6.0;
  /// Extremely high variance is usually sensor noise / failure, not a palm.
  static const maxBlur = 20000.0;

  static const minFingerSkinRatio = 0.30;
  static const manualMinFingerSkinRatio = 0.25;

  /// Max normalized distance of skin mass from palm-path center (0..~0.7).
  static const maxCentroidDistance = 0.26;
  static const manualMaxCentroidDistance = 0.30;

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
    final fingerBand = Rect.fromLTWH(
      0,
      0,
      roi.width.toDouble(),
      roi.height * 0.35,
    );

    var lumaSum = 0.0;
    var lumaCount = 0;
    var insideSkin = 0;
    var insideCount = 0;
    var outsideSkin = 0;
    var outsideCount = 0;
    var fingerSkin = 0;
    var fingerCount = 0;
    var skinSumX = 0.0;
    var skinSumY = 0.0;
    var skinMass = 0;
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
        final pt = Offset(x + 0.5, y + 0.5);
        final inPalm = palm.contains(pt);
        final inFingers = inPalm && fingerBand.contains(pt);

        if (inFingers) {
          fingerCount++;
          if (skin) {
            fingerSkin++;
          }
        }

        if (inPalm) {
          insideCount++;
          lumaSum += yLuma;
          lumaCount++;
          if (skin) {
            insideSkin++;
            skinSumX += x + 0.5;
            skinSumY += y + 0.5;
            skinMass++;
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
    final outsideSkinRatio =
        outsideCount == 0 ? 0.0 : outsideSkin / outsideCount;
    final roiSkinRatio =
        (insideCount + outsideCount) == 0
            ? 0.0
            : (insideSkin + outsideSkin) / (insideCount + outsideCount);
    final fingerSkinRatio =
        fingerCount == 0 ? 0.0 : fingerSkin / fingerCount;
    final blur = _laplacianVariance(gray, roi.width, roi.height);

    final palmCenter = Offset(roi.width * 0.5, roi.height * 0.52);
    final diag = math.sqrt(
      roi.width * roi.width + roi.height * roi.height,
    );
    var centroidDistance = 1.0;
    if (skinMass > 0 && diag > 0) {
      final cx = skinSumX / skinMass;
      final cy = skinSumY / skinMass;
      centroidDistance =
          Offset(cx - palmCenter.dx, cy - palmCenter.dy).distance / diag;
    }
    final centroidOk = skinMass > 0 &&
        centroidDistance <=
            (strict ? maxCentroidDistance : manualMaxCentroidDistance);

    PalmQualityResult fail(String message) {
      return PalmQualityResult(
        ok: false,
        message: message,
        brightness: brightness,
        blur: blur,
        skinRatio: insideSkinRatio,
        outsideSkinRatio: outsideSkinRatio,
        roiSkinRatio: roiSkinRatio,
        fingerSkinRatio: fingerSkinRatio,
        centroidOk: centroidOk,
      );
    }

    final skinMin = strict ? minInsideSkinRatio : manualMinInsideSkinRatio;
    final contrastMin = strict ? minSkinContrast : manualMinSkinContrast;
    final outsideMax =
        strict ? maxOutsideSkinRatio : manualMaxOutsideSkinRatio;
    final roiSkinMax = strict ? maxRoiSkinRatio : manualMaxRoiSkinRatio;
    final blurMin = strict ? minBlur : manualMinBlur;
    final fingerMin =
        strict ? minFingerSkinRatio : manualMinFingerSkinRatio;

    if (brightness < minBrightness) {
      return fail('Too dark. Face your palm toward the light.');
    }
    if (brightness > maxBrightness) {
      return fail('Too bright. Move a little away from the light.');
    }
    if (blur < blurMin) {
      return fail('Hold still — image is too soft to read.');
    }
    if (blur > maxBlur) {
      return fail('Too much noise. Soften the lighting a little.');
    }
    if (insideSkinRatio < skinMin) {
      return fail('Place your open palm inside the outline.');
    }
    if (insideSkinRatio - outsideSkinRatio < contrastMin) {
      return fail('Center your palm — background looks like skin.');
    }
    if (outsideSkinRatio > outsideMax) {
      return fail('Only your palm should fill the guide — step closer.');
    }
    if (roiSkinRatio > roiSkinMax) {
      return fail('Too close. Pull your hand back into the guide.');
    }
    if (!centroidOk) {
      return fail('Center your palm in the outline.');
    }
    if (fingerSkinRatio < fingerMin) {
      return fail('Open your fingers inside the top of the guide.');
    }

    return PalmQualityResult(
      ok: true,
      message: 'Palm looks clear. Hold still…',
      brightness: brightness,
      blur: blur,
      skinRatio: insideSkinRatio,
      outsideSkinRatio: outsideSkinRatio,
      roiSkinRatio: roiSkinRatio,
      fingerSkinRatio: fingerSkinRatio,
      centroidOk: centroidOk,
    );
  }

  static img.Image _forAnalysis(img.Image roi) {
    if (roi.width <= analysisMaxWidth) {
      return roi;
    }
    final height =
        math.max(8, (roi.height * (analysisMaxWidth / roi.width)).round());
    return img.copyResize(roi, width: analysisMaxWidth, height: height);
  }

  /// Require YCbCr and Kovac RGB agreement — fewer false skins.
  static bool _isSkin(int r, int g, int b) {
    return _isYcbCrSkin(r, g, b) && _isRgbSkin(r, g, b);
  }

  static bool _isYcbCrSkin(int r, int g, int b) {
    final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
    final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
    return cb >= 77 && cb <= 127 && cr >= 133 && cr <= 173;
  }

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
        final lap = gray[(y - 1) * width + x] +
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
