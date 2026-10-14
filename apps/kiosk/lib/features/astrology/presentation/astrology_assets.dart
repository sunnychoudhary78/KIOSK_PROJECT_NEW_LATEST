import 'package:flutter/material.dart';

/// Paths and mappers for astrology illustration assets.
abstract final class AstrologyAssets {
  static const sealMedallion = 'assets/astrology/seal_medallion.jpg';
  static const backdropNebula = 'assets/astrology/backdrop_nebula.jpg';

  static const ritualAlign = 'assets/astrology/ritual_align.jpg';
  static const ritualHold = 'assets/astrology/ritual_hold.jpg';
  static const ritualCapture = 'assets/astrology/ritual_capture.jpg';

  static const palmLife = 'assets/astrology/palm_life.jpg';
  static const palmHeart = 'assets/astrology/palm_heart.jpg';
  static const palmHead = 'assets/astrology/palm_head.jpg';
  static const palmFate = 'assets/astrology/palm_fate.jpg';

  static const glyphSun = 'assets/astrology/glyph_sun.jpg';
  static const glyphMoon = 'assets/astrology/glyph_moon.jpg';
  static const glyphNakshatra = 'assets/astrology/glyph_nakshatra.jpg';
  static const glyphDasha = 'assets/astrology/glyph_dasha.jpg';
  static const glyphLagna = 'assets/astrology/glyph_lagna.jpg';

  static const _zodiac = <String, String>{
    'aries': 'assets/astrology/zodiac_aries.jpg',
    'mesha': 'assets/astrology/zodiac_aries.jpg',
    'taurus': 'assets/astrology/zodiac_taurus.jpg',
    'vrishabha': 'assets/astrology/zodiac_taurus.jpg',
    'vrishabh': 'assets/astrology/zodiac_taurus.jpg',
    'gemini': 'assets/astrology/zodiac_gemini.jpg',
    'mithuna': 'assets/astrology/zodiac_gemini.jpg',
    'cancer': 'assets/astrology/zodiac_cancer.jpg',
    'karka': 'assets/astrology/zodiac_cancer.jpg',
    'karkata': 'assets/astrology/zodiac_cancer.jpg',
    'leo': 'assets/astrology/zodiac_leo.jpg',
    'simha': 'assets/astrology/zodiac_leo.jpg',
    'virgo': 'assets/astrology/zodiac_virgo.jpg',
    'kanya': 'assets/astrology/zodiac_virgo.jpg',
    'libra': 'assets/astrology/zodiac_libra.jpg',
    'tula': 'assets/astrology/zodiac_libra.jpg',
    'scorpio': 'assets/astrology/zodiac_scorpio.jpg',
    'scorpion': 'assets/astrology/zodiac_scorpio.jpg',
    'vrischika': 'assets/astrology/zodiac_scorpio.jpg',
    'vrishchika': 'assets/astrology/zodiac_scorpio.jpg',
    'sagittarius': 'assets/astrology/zodiac_sagittarius.jpg',
    'dhanu': 'assets/astrology/zodiac_sagittarius.jpg',
    'dhanus': 'assets/astrology/zodiac_sagittarius.jpg',
    'capricorn': 'assets/astrology/zodiac_capricorn.jpg',
    'makara': 'assets/astrology/zodiac_capricorn.jpg',
    'aquarius': 'assets/astrology/zodiac_aquarius.jpg',
    'kumbha': 'assets/astrology/zodiac_aquarius.jpg',
    'pisces': 'assets/astrology/zodiac_pisces.jpg',
    'meena': 'assets/astrology/zodiac_pisces.jpg',
  };

  static String _normalize(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');
  }

  /// Returns a zodiac asset when [label] looks like a sign name.
  static String? zodiacAssetFor(String? label) {
    if (label == null || label.trim().isEmpty) {
      return null;
    }
    final key = _normalize(label);
    final direct = _zodiac[key];
    if (direct != null) {
      return direct;
    }
    for (final entry in _zodiac.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Chart metric glyph for Lagna / Sun / Moon / Nakshatra / Dasha labels.
  static String? chartGlyphFor(String? label) {
    if (label == null || label.trim().isEmpty) {
      return null;
    }
    final key = _normalize(label);
    if (key.contains('lagna') || key.contains('ascendant')) {
      return glyphLagna;
    }
    if (key == 'sun' || key.contains('surya')) {
      return glyphSun;
    }
    if (key == 'moon' || key.contains('chandra')) {
      return glyphMoon;
    }
    if (key.contains('nakshatra')) {
      return glyphNakshatra;
    }
    if (key.contains('dasha')) {
      return glyphDasha;
    }
    return null;
  }

  /// Best illustration for a chart tile: zodiac from value, else glyph from label.
  static String? chartArtFor({required String label, required String value}) {
    return zodiacAssetFor(value) ?? chartGlyphFor(label) ?? zodiacAssetFor(label);
  }

  static String? palmLineAssetFor(String title) {
    final key = _normalize(title);
    if (key.contains('life')) {
      return palmLife;
    }
    if (key.contains('heart')) {
      return palmHeart;
    }
    if (key.contains('head')) {
      return palmHead;
    }
    if (key.contains('fate')) {
      return palmFate;
    }
    return null;
  }

  static String ritualAssetForIndex(int index) {
    return switch (index) {
      0 => ritualAlign,
      1 => ritualHold,
      _ => ritualCapture,
    };
  }
}

/// Soft fade-in asset image for astrology chrome.
class AstrologyAssetImage extends StatelessWidget {
  const AstrologyAssetImage({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.opacity = 1,
    this.borderRadius,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double opacity;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          SizedBox(width: width, height: height),
    );
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    if (opacity < 1) {
      image = Opacity(opacity: opacity, child: image);
    }
    return image;
  }
}
