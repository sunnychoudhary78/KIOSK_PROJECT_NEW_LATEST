import 'package:skp_kiosk/features/astrology/domain/astrology_insights.dart';

/// UI + chart-value localization for My Kundali result (EN/HI).
abstract final class KundaliLocale {
  static String insightsTitle(AstrologyInsightLocale locale) =>
      locale == AstrologyInsightLocale.hi ? 'एआई अंतर्दृष्टि' : 'AI insights';

  static String styleLabel(String style, AstrologyInsightLocale locale) {
    final south = style == 'south';
    if (locale == AstrologyInsightLocale.hi) {
      return south ? 'दक्षिण भारतीय' : 'उत्तर भारतीय';
    }
    return south ? 'South Indian' : 'North Indian';
  }

  static String chartTabTitle(String chartKey, AstrologyInsightLocale locale) {
    if (locale == AstrologyInsightLocale.hi) {
      return switch (chartKey) {
        'RasiD1' => 'जन्म',
        'NavamshaD9' => 'विवाह',
        'DashamamshaD10' => 'करियर',
        _ => chartKey,
      };
    }
    return switch (chartKey) {
      'RasiD1' => 'Birth',
      'NavamshaD9' => 'Marriage',
      'DashamamshaD10' => 'Career',
      _ => chartKey,
    };
  }

  static String fieldLabel(String key, AstrologyInsightLocale locale) {
    if (locale == AstrologyInsightLocale.hi) {
      return switch (key) {
        'lagna' => 'लग्न',
        'sun' => 'सूर्य',
        'moon' => 'चंद्र',
        'nakshatra' => 'नक्षत्र',
        'dasha' => 'दशा',
        _ => key,
      };
    }
    return switch (key) {
      'lagna' => 'Lagna',
      'sun' => 'Sun',
      'moon' => 'Moon',
      'nakshatra' => 'Nakshatra',
      'dasha' => 'Dasha',
      _ => key,
    };
  }

  /// Localize a chart value (sign, nakshatra, dasha chain). Unknown tokens kept as-is.
  static String localizeChartValue(String raw, AstrologyInsightLocale locale) {
    if (locale == AstrologyInsightLocale.en || raw.trim().isEmpty) {
      return raw;
    }
    return raw.split(RegExp(r'\s*[-–—,/]\s*')).map((part) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) return trimmed;
      // Preserve pada suffix like "1" after nakshatra.
      final match = RegExp(r'^(.+?)(?:\s+(\d+))?$').firstMatch(trimmed);
      if (match == null) return trimmed;
      final name = match.group(1)!.trim();
      final pada = match.group(2);
      final localized = _lookupHi(name) ?? name;
      return pada == null ? localized : '$localized $pada';
    }).join(' - ');
  }

  static String? _lookupHi(String name) {
    final key = _normalize(name);
    return _hiNames[key];
  }

  static String _normalize(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');
  }

  /// English + Sanskrit aliases → Hindi display.
  static const _hiNames = <String, String>{
    // Zodiac
    'aries': 'मेष',
    'mesha': 'मेष',
    'taurus': 'वृषभ',
    'vrishabha': 'वृषभ',
    'vrishabh': 'वृषभ',
    'gemini': 'मिथुन',
    'mithuna': 'मिथुन',
    'cancer': 'कर्क',
    'karka': 'कर्क',
    'karkata': 'कर्क',
    'leo': 'सिंह',
    'simha': 'सिंह',
    'virgo': 'कन्या',
    'kanya': 'कन्या',
    'libra': 'तुला',
    'tula': 'तुला',
    'scorpio': 'वृश्चिक',
    'scorpion': 'वृश्चिक',
    'vrischika': 'वृश्चिक',
    'vrishchika': 'वृश्चिक',
    'sagittarius': 'धनु',
    'dhanu': 'धनु',
    'dhanus': 'धनु',
    'capricorn': 'मकर',
    'makara': 'मकर',
    'aquarius': 'कुंभ',
    'kumbha': 'कुंभ',
    'pisces': 'मीन',
    'meena': 'मीन',
    // Planets (dasha)
    'sun': 'सूर्य',
    'surya': 'सूर्य',
    'moon': 'चंद्र',
    'chandra': 'चंद्र',
    'mars': 'मंगल',
    'mangal': 'मंगल',
    'mangala': 'मंगल',
    'mercury': 'बुध',
    'budha': 'बुध',
    'jupiter': 'गुरु',
    'guru': 'गुरु',
    'brihaspati': 'गुरु',
    'venus': 'शुक्र',
    'shukra': 'शुक्र',
    'saturn': 'शनि',
    'shani': 'शनि',
    'rahu': 'राहु',
    'ketu': 'केतु',
    // Common nakshatras
    'ashwini': 'अश्विनी',
    'aswini': 'अश्विनी',
    'bharani': 'भरणी',
    'krittika': 'कृत्तिका',
    'rohini': 'रोहिणी',
    'mrigashira': 'मृगशिरा',
    'mrigashirsha': 'मृगशिरा',
    'ardra': 'आर्द्रा',
    'punarvasu': 'पुनर्वसु',
    'pushya': 'पुष्य',
    'ashlesha': 'आश्लेषा',
    'magha': 'मघा',
    'purvaphalguni': 'पूर्वाफाल्गुनी',
    'poorvaphalguni': 'पूर्वाफाल्गुनी',
    'uttaraphalguni': 'उत्तराफाल्गुनी',
    'hasta': 'हस्त',
    'chitra': 'चित्रा',
    'swati': 'स्वाती',
    'swathi': 'स्वाती',
    'vishakha': 'विशाखा',
    'anuradha': 'अनुराधा',
    'jyeshtha': 'ज्येष्ठा',
    'jyestha': 'ज्येष्ठा',
    'mula': 'मूल',
    'moola': 'मूल',
    'purvashada': 'पूर्वाषाढ़ा',
    'poorvashada': 'पूर्वाषाढ़ा',
    'purvashadha': 'पूर्वाषाढ़ा',
    'poorvashadha': 'पूर्वाषाढ़ा',
    'uttarashada': 'उत्तराषाढ़ा',
    'uttarashadha': 'उत्तराषाढ़ा',
    'shravana': 'श्रवण',
    'sravana': 'श्रवण',
    'dhanishta': 'धनिष्ठा',
    'dhanishtha': 'धनिष्ठा',
    'shatabhisha': 'शतभिषा',
    'satabhisha': 'शतभिषा',
    'purvabhadrapada': 'पूर्वाभाद्रपद',
    'poorvabhadrapada': 'पूर्वाभाद्रपद',
    'uttarabhadrapada': 'उत्तराभाद्रपद',
    'revati': 'रेवती',
  };
}
