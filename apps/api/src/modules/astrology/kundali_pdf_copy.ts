import type { ChartSummary } from './astrology.schemas.js';

export type KundaliPdfLocale = 'en' | 'hi';

const HI_NAMES: Record<string, string> = {
  aries: 'मेष',
  mesha: 'मेष',
  taurus: 'वृषभ',
  vrishabha: 'वृषभ',
  vrishabh: 'वृषभ',
  gemini: 'मिथुन',
  mithuna: 'मिथुन',
  cancer: 'कर्क',
  karka: 'कर्क',
  karkata: 'कर्क',
  leo: 'सिंह',
  simha: 'सिंह',
  virgo: 'कन्या',
  kanya: 'कन्या',
  libra: 'तुला',
  tula: 'तुला',
  scorpio: 'वृश्चिक',
  scorpion: 'वृश्चिक',
  vrischika: 'वृश्चिक',
  vrishchika: 'वृश्चिक',
  sagittarius: 'धनु',
  dhanu: 'धनु',
  dhanus: 'धनु',
  capricorn: 'मकर',
  makara: 'मकर',
  aquarius: 'कुंभ',
  kumbha: 'कुंभ',
  pisces: 'मीन',
  meena: 'मीन',
  sun: 'सूर्य',
  surya: 'सूर्य',
  moon: 'चंद्र',
  chandra: 'चंद्र',
  mars: 'मंगल',
  mangal: 'मंगल',
  mangala: 'मंगल',
  mercury: 'बुध',
  budha: 'बुध',
  jupiter: 'गुरु',
  guru: 'गुरु',
  brihaspati: 'गुरु',
  venus: 'शुक्र',
  shukra: 'शुक्र',
  saturn: 'शनि',
  shani: 'शनि',
  rahu: 'राहु',
  ketu: 'केतु',
  ashwini: 'अश्विनी',
  aswini: 'अश्विनी',
  bharani: 'भरणी',
  krittika: 'कृत्तिका',
  rohini: 'रोहिणी',
  mrigashira: 'मृगशिरा',
  mrigashirsha: 'मृगशिरा',
  ardra: 'आर्द्रा',
  punarvasu: 'पुनर्वसु',
  pushya: 'पुष्य',
  ashlesha: 'आश्लेषा',
  magha: 'मघा',
  purvaphalguni: 'पूर्वाफाल्गुनी',
  poorvaphalguni: 'पूर्वाफाल्गुनी',
  uttaraphalguni: 'उत्तराफाल्गुनी',
  hasta: 'हस्त',
  chitra: 'चित्रा',
  swati: 'स्वाती',
  swathi: 'स्वाती',
  vishakha: 'विशाखा',
  anuradha: 'अनुराधा',
  jyeshtha: 'ज्येष्ठा',
  jyestha: 'ज्येष्ठा',
  mula: 'मूल',
  moola: 'मूल',
  purvashada: 'पूर्वाषाढ़ा',
  poorvashada: 'पूर्वाषाढ़ा',
  purvashadha: 'पूर्वाषाढ़ा',
  poorvashadha: 'पूर्वाषाढ़ा',
  uttarashada: 'उत्तराषाढ़ा',
  uttarashadha: 'उत्तराषाढ़ा',
  shravana: 'श्रवण',
  sravana: 'श्रवण',
  dhanishta: 'धनिष्ठा',
  dhanishtha: 'धनिष्ठा',
  shatabhisha: 'शतभिषा',
  satabhisha: 'शतभिषा',
  purvabhadrapada: 'पूर्वाभाद्रपद',
  poorvabhadrapada: 'पूर्वाभाद्रपद',
  uttarabhadrapada: 'उत्तराभाद्रपद',
  revati: 'रेवती',
};

function normalizeName(raw: string): string {
  return raw.trim().toLowerCase().replace(/[^a-z]/g, '');
}

/** English sign, planet, nakshatra, and dasha names → Hindi. Unknown tokens stay. */
export function localizeChartValue(raw: string, locale: KundaliPdfLocale): string {
  if (locale === 'en' || raw.trim().length === 0) return raw;
  return raw
    .split(/\s*[-–—,/]\s*/)
    .map((part) => {
      const trimmed = part.trim();
      if (!trimmed) return trimmed;
      const match = /^(.+?)(?:\s+(\d+))?$/.exec(trimmed);
      if (!match) return trimmed;
      const name = match[1]?.trim();
      if (!name) return trimmed;
      const pada = match[2];
      const localized = HI_NAMES[normalizeName(name)] ?? name;
      return pada == null ? localized : `${localized} ${pada}`;
    })
    .join(' - ');
}

export function kundaliStyleLabel(style: 'north' | 'south', locale: KundaliPdfLocale): string {
  const south = style === 'south';
  if (locale === 'hi') return south ? 'दक्षिण भारतीय' : 'उत्तर भारतीय';
  return south ? 'South Indian' : 'North Indian';
}

export function kundaliChartTitle(key: string, fallback: string, locale: KundaliPdfLocale): string {
  if (locale === 'hi') {
    if (key === 'RasiD1') return 'जन्म';
    if (key === 'NavamshaD9') return 'विवाह';
    if (key === 'DashamamshaD10') return 'करियर';
  }
  if (key === 'RasiD1') return 'Birth';
  if (key === 'NavamshaD9') return 'Marriage';
  if (key === 'DashamamshaD10') return 'Career';
  return fallback;
}

export function kundaliChartSubtitle(key: string, fallback: string, locale: KundaliPdfLocale): string {
  if (locale === 'hi') {
    if (key === 'RasiD1') return 'राशि';
    if (key === 'NavamshaD9') return 'नवांश';
    if (key === 'DashamamshaD10') return 'दशांश';
  }
  return fallback;
}

type Copy = {
  name: string;
  birth: string;
  time: string;
  place: string;
  style: string;
  lagna: string;
  sun: string;
  moon: string;
  nakshatra: string;
  dasha: string;
  chart: string;
  charts: string;
  reading: string;
  approx: string;
  disclaimer: string;
  footer: string;
  chartFailed: (title: string) => string;
  reportSubtitle: (title: string) => string;
};

const EN: Copy = {
  name: 'Name',
  birth: 'Birth',
  time: 'Time',
  place: 'Place',
  style: 'Style',
  lagna: 'Lagna',
  sun: 'Sun',
  moon: 'Moon',
  nakshatra: 'Nakshatra',
  dasha: 'Dasha',
  chart: 'Chart',
  charts: 'Charts',
  reading: 'Reading',
  approx: 'approx.',
  disclaimer: 'For entertainment only. Not medical, legal, or financial advice.',
  footer: 'Printed at ATHENA kiosk | For personal reference only',
  chartFailed: (title) => `Chart ${title} could not be rendered for print.`,
  reportSubtitle: (title) => `${title} chart report`,
};

const HI: Copy = {
  name: 'नाम',
  birth: 'जन्म',
  time: 'समय',
  place: 'स्थान',
  style: 'शैली',
  lagna: 'लग्न',
  sun: 'सूर्य',
  moon: 'चंद्र',
  nakshatra: 'नक्षत्र',
  dasha: 'दशा',
  chart: 'कुंडली',
  charts: 'कुंडलियाँ',
  reading: 'विवरण',
  approx: 'अनुमानित',
  disclaimer: 'केवल मनोरंजन के लिए। यह चिकित्सा, कानूनी या वित्तीय सलाह नहीं है।',
  footer: 'ATHENA कियोस्क पर मुद्रित | केवल व्यक्तिगत संदर्भ',
  chartFailed: (title) => `${title} चार्ट प्रिंट के लिए नहीं बन सका।`,
  reportSubtitle: (title) => `${title} कुंडली`,
};

const KUTA_HI: Record<string, string> = {
  varna: 'वर्ण',
  vashya: 'वश्य',
  vasya: 'वश्य',
  tara: 'तारा',
  yoni: 'योनि',
  grahmaitri: 'ग्रह मैत्री',
  grahamaitri: 'ग्रह मैत्री',
  maitri: 'मैत्री',
  gana: 'गण',
  bhakoot: 'भकूट',
  bhakut: 'भकूट',
  nadi: 'नाड़ी',
};

const TONE_HI: Record<string, string> = {
  good: 'अच्छा',
  average: 'औसत',
  poor: 'कमजोर',
  bad: 'खराब',
};

export function localizeKutaName(name: string, locale: KundaliPdfLocale): string {
  if (locale === 'en') return name;
  return KUTA_HI[normalizeName(name)] ?? name;
}

export function localizeTone(tone: string, locale: KundaliPdfLocale): string {
  if (locale === 'en') return tone;
  return TONE_HI[normalizeName(tone)] ?? tone;
}

export function kundaliPdfCopy(locale: KundaliPdfLocale): Copy {
  return locale === 'hi' ? HI : EN;
}

export function chartFactLine(chart: ChartSummary, locale: KundaliPdfLocale): string | null {
  const copy = kundaliPdfCopy(locale);
  const bits = [
    chart.lagna ? `${copy.lagna} ${localizeChartValue(chart.lagna, locale)}` : null,
    chart.sunSign ? `${copy.sun} ${localizeChartValue(chart.sunSign, locale)}` : null,
    chart.moonSign ? `${copy.moon} ${localizeChartValue(chart.moonSign, locale)}` : null,
    chart.nakshatra ? `${copy.nakshatra} ${localizeChartValue(chart.nakshatra, locale)}` : null,
    chart.currentDasha ? `${copy.dasha} ${localizeChartValue(chart.currentDasha, locale)}` : null,
  ].filter((bit): bit is string => Boolean(bit));
  return bits.length > 0 ? bits.join(' | ') : null;
}
