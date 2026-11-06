import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildReportPdf, svgToPng, type ReportLine, type ReportPdfFontBytes } from '../printing/report_pdf.js';
import {
  chartFactLine,
  kundaliChartSubtitle,
  kundaliChartTitle,
  kundaliPdfCopy,
  kundaliStyleLabel,
  localizeChartValue,
  localizeKutaName,
  localizeTone,
  type KundaliPdfLocale,
} from './kundali_pdf_copy.js';
import { ASTROLOGY_DISCLAIMER, type ChartSummary, type ReadingSubject } from './astrology.schemas.js';

let kundaliFonts: ReportPdfFontBytes | undefined;

function loadKundaliFonts(): ReportPdfFontBytes {
  if (kundaliFonts) return kundaliFonts;
  const dir = join(dirname(fileURLToPath(import.meta.url)), '../../../assets/fonts');
  kundaliFonts = {
    regular: readFileSync(join(dir, 'NotoSansDevanagari-Regular.ttf')),
    bold: readFileSync(join(dir, 'NotoSansDevanagari-Bold.ttf')),
  };
  return kundaliFonts;
}

function pdfLocale(locale?: 'en' | 'hi'): KundaliPdfLocale {
  return locale === 'hi' ? 'hi' : 'en';
}

function premiumReport(
  input: Omit<Parameters<typeof buildReportPdf>[0], 'fonts' | 'preserveUnicode' | 'premiumHeader'>,
): Promise<Buffer> {
  return buildReportPdf({
    ...input,
    fonts: loadKundaliFonts(),
    preserveUnicode: true,
    premiumHeader: true,
  });
}

function personLines(
  subject: ReadingSubject,
  locale: KundaliPdfLocale,
  heading: string,
): ReportLine[] {
  const copy = kundaliPdfCopy(locale);
  const time = subject.birthTimeUnknown
    ? `${subject.birthTime} (${copy.approx})`
    : subject.birthTime;
  return [
    { kind: 'heading', text: heading },
    { kind: 'kv', label: copy.name, value: subject.name },
    { kind: 'kv', label: copy.birth, value: subject.dateOfBirth },
    { kind: 'kv', label: copy.time, value: time },
    { kind: 'kv', label: copy.place, value: subject.birthPlace },
  ];
}

function subjectLines(subject: ReadingSubject, heading = 'Birth details'): ReportLine[] {
  return [
    { kind: 'heading', text: heading },
    { kind: 'kv', label: 'Name', value: subject.name },
    { kind: 'kv', label: 'Gender', value: subject.gender },
    { kind: 'kv', label: 'Date of birth', value: subject.dateOfBirth },
    {
      kind: 'kv',
      label: 'Birth time',
      value: subject.birthTimeUnknown ? `${subject.birthTime} (approx.)` : subject.birthTime,
    },
    { kind: 'kv', label: 'Birth place', value: subject.birthPlace },
  ];
}

function chartSummaryLines(chart: ChartSummary): ReportLine[] {
  const rows: ReportLine[] = [{ kind: 'heading', text: 'Chart summary' }];
  if (chart.lagna) rows.push({ kind: 'kv', label: 'Lagna', value: chart.lagna });
  if (chart.sunSign) rows.push({ kind: 'kv', label: 'Sun', value: chart.sunSign });
  if (chart.moonSign) rows.push({ kind: 'kv', label: 'Moon', value: chart.moonSign });
  if (chart.nakshatra) rows.push({ kind: 'kv', label: 'Nakshatra', value: chart.nakshatra });
  if (chart.currentDasha) rows.push({ kind: 'kv', label: 'Current dasha', value: chart.currentDasha });
  if (rows.length === 1) {
    rows.push({ kind: 'muted', text: 'No chart summary available.' });
  }
  return rows;
}

function insightLines(
  bullets: string[] | undefined,
  heading = 'AI insights',
): ReportLine[] {
  if (!bullets || bullets.length === 0) return [];
  const lines: ReportLine[] = [
    { kind: 'spacer', height: 8 },
    { kind: 'heading', text: heading },
  ];
  for (const bullet of bullets) {
    lines.push({ kind: 'body', text: `- ${bullet}` });
  }
  return lines;
}

export type KundaliPrintPdfInput = {
  subject: ReadingSubject;
  style: 'north' | 'south';
  chart: ChartSummary;
  charts: Array<{ key: string; title: string; subtitle: string; svg: string }>;
  insights?: Array<{ key: string; title: string; bullets: string[] }>;
  locale?: 'en' | 'hi';
  disclaimer?: string;
};

export async function buildKundaliReportPdf(input: KundaliPrintPdfInput): Promise<Buffer> {
  const locale: KundaliPdfLocale = input.locale === 'hi' ? 'hi' : 'en';
  const copy = kundaliPdfCopy(locale);
  const primary = input.charts[0];
  const singleChart = input.charts.length === 1;
  const hasInsights = (input.insights ?? []).some((section) => section.bullets.length > 0);
  const chartMaxHeight = singleChart ? (hasInsights ? 280 : 360) : 360;
  const timeValue = input.subject.birthTimeUnknown
    ? `${input.subject.birthTime} (${copy.approx})`
    : input.subject.birthTime;

  const lines: ReportLine[] = [];

  if (singleChart) {
    lines.push({ kind: 'kv', label: copy.birth, value: input.subject.dateOfBirth });
    lines.push({ kind: 'kv', label: copy.time, value: timeValue });
    lines.push({ kind: 'kv', label: copy.place, value: input.subject.birthPlace });
    lines.push({
      kind: 'kv',
      label: copy.style,
      value: kundaliStyleLabel(input.style, locale),
    });
    const facts = chartFactLine(input.chart, locale);
    if (facts) {
      lines.push({ kind: 'kv', label: copy.chart, value: facts });
    }
    lines.push({ kind: 'spacer', height: 4 });
    if (primary) {
      const title = kundaliChartTitle(primary.key, primary.title, locale);
      const subtitle = kundaliChartSubtitle(primary.key, primary.subtitle, locale);
      lines.push({ kind: 'heading', text: `${title} | ${subtitle}` });
    }
  } else {
    lines.push(...subjectLines(input.subject));
    lines.push({ kind: 'spacer', height: 4 });
    lines.push({
      kind: 'kv',
      label: copy.style,
      value: kundaliStyleLabel(input.style, locale),
    });
    lines.push({ kind: 'spacer', height: 4 });
    lines.push(...chartSummaryLines(input.chart));
    lines.push({ kind: 'spacer', height: 6 });
    lines.push({ kind: 'heading', text: copy.charts });
  }

  for (const chart of input.charts) {
    const title = kundaliChartTitle(chart.key, chart.title, locale);
    const subtitle = kundaliChartSubtitle(chart.key, chart.subtitle, locale);
    try {
      const png = svgToPng(chart.svg, singleChart ? 1100 : 1000);
      if (!singleChart) {
        lines.push({ kind: 'subheading', text: `${title} | ${subtitle}` });
      }
      lines.push({
        kind: 'image',
        bytes: png,
        format: 'png',
        maxHeight: chartMaxHeight,
        frame: true,
      });
    } catch {
      lines.push({
        kind: 'muted',
        text: copy.chartFailed(title),
      });
    }
  }

  if (hasInsights) {
    if (singleChart) {
      const bullets = (input.insights ?? []).flatMap((section) => section.bullets);
      lines.push(...insightLines(bullets, copy.reading));
    } else {
      lines.push({ kind: 'spacer', height: 8 });
      lines.push({ kind: 'heading', text: copy.reading });
      for (const section of input.insights ?? []) {
        if (section.bullets.length === 0) continue;
        lines.push({
          kind: 'subheading',
          text: kundaliChartTitle(section.key, section.title, locale),
        });
        for (const bullet of section.bullets) {
          lines.push({ kind: 'body', text: `- ${bullet}` });
        }
      }
    }
  }

  const chartTitle = primary
    ? kundaliChartTitle(primary.key, primary.title, locale)
    : locale === 'hi'
      ? 'जन्म'
      : 'Birth';

  return buildReportPdf({
    title: input.subject.name,
    subtitle: copy.reportSubtitle(chartTitle),
    lines,
    disclaimer: locale === 'hi' ? copy.disclaimer : (input.disclaimer ?? ASTROLOGY_DISCLAIMER),
    fonts: loadKundaliFonts(),
    preserveUnicode: true,
    premiumHeader: true,
    bandLabel: locale === 'hi' ? 'कुंडली' : 'Kundali',
    footer: copy.footer,
  });
}

export type MatchPrintPdfInput = {
  groom: ReadingSubject;
  bride: ReadingSubject;
  score: { total: number; max: number; summary: string; tone: string };
  kutas: Array<{
    name: string;
    maxPoints: number;
    points?: number;
    nature?: string;
    verdict?: string;
  }>;
  accuracyNote?: string;
  insightBullets?: string[];
  locale?: 'en' | 'hi';
  disclaimer?: string;
};

export async function buildMatchReportPdf(input: MatchPrintPdfInput): Promise<Buffer> {
  const locale = pdfLocale(input.locale);
  const hi = locale === 'hi';
  const copy = kundaliPdfCopy(locale);
  const lines: ReportLine[] = [
    ...personLines(input.groom, locale, hi ? 'वर' : 'Groom'),
    { kind: 'spacer', height: 8 },
    ...personLines(input.bride, locale, hi ? 'वधू' : 'Bride'),
    { kind: 'spacer', height: 10 },
    { kind: 'heading', text: hi ? 'गुण मिलान' : 'Gun Milan score' },
    {
      kind: 'kv',
      label: hi ? 'अंक' : 'Score',
      value: `${input.score.total} / ${input.score.max} (${localizeTone(input.score.tone, locale)})`,
    },
    { kind: 'body', text: input.score.summary },
    { kind: 'spacer', height: 8 },
    { kind: 'heading', text: hi ? 'कूट' : 'Kutas' },
  ];

  for (const kuta of input.kutas) {
    const points = kuta.points == null ? '-' : String(kuta.points);
    const verdict = kuta.verdict ? localizeTone(kuta.verdict, locale) : '';
    lines.push({
      kind: 'kv',
      label: localizeKutaName(kuta.name, locale),
      value: `${points} / ${kuta.maxPoints}${verdict ? ` | ${verdict}` : ''}${
        kuta.nature ? ` (${kuta.nature})` : ''
      }`,
    });
  }

  lines.push(...insightLines(input.insightBullets, copy.reading));

  if (input.accuracyNote) {
    lines.push({ kind: 'spacer', height: 8 });
    lines.push({ kind: 'muted', text: input.accuracyNote });
  }

  return premiumReport({
    title: `${input.groom.name} & ${input.bride.name}`,
    subtitle: hi ? 'अनुकूलता' : 'Compatibility report',
    bandLabel: hi ? 'मिलान' : 'Match',
    lines,
    disclaimer: hi ? copy.disclaimer : (input.disclaimer ?? ASTROLOGY_DISCLAIMER),
    footer: copy.footer,
  });
}

export type PalmPrintPdfInput = {
  subject: ReadingSubject;
  chart: ChartSummary;
  palm: {
    summary: string;
    lifeLine: string;
    heartLine: string;
    headLine: string;
    fateLine: string;
  };
  reading: {
    overview: string;
    personality: string;
    career: string;
    health: string;
    relationships: string;
    period: string;
  };
  palmJpegBase64?: string;
  disclaimer?: string;
};

export async function buildPalmReportPdf(input: PalmPrintPdfInput): Promise<Buffer> {
  const copy = kundaliPdfCopy('en');
  const lines: ReportLine[] = [
    ...personLines(input.subject, 'en', 'Birth details'),
    { kind: 'spacer', height: 8 },
  ];
  const facts = chartFactLine(input.chart, 'en');
  if (facts) {
    lines.push({ kind: 'kv', label: copy.chart, value: facts });
    lines.push({ kind: 'spacer', height: 8 });
  }

  if (input.palmJpegBase64) {
    try {
      const raw = input.palmJpegBase64.includes(',')
        ? input.palmJpegBase64.split(',').pop()!
        : input.palmJpegBase64;
      const bytes = Buffer.from(raw, 'base64');
      const isPng =
        bytes.length >= 8 &&
        bytes[0] === 0x89 &&
        bytes[1] === 0x50 &&
        bytes[2] === 0x4e &&
        bytes[3] === 0x47;
      const isJpg =
        bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
      if (isPng || isJpg) {
        lines.push({ kind: 'heading', text: 'Palm photo' });
        lines.push({
          kind: 'image',
          bytes,
          format: isPng ? 'png' : 'jpg',
          maxHeight: 280,
          frame: true,
        });
      }
    } catch {
      // Ignore invalid palm image for print.
    }
  }

  lines.push({ kind: 'heading', text: 'Palm lines' });
  lines.push({ kind: 'body', text: input.palm.summary });
  lines.push({ kind: 'kv', label: 'Life line', value: input.palm.lifeLine });
  lines.push({ kind: 'kv', label: 'Heart line', value: input.palm.heartLine });
  lines.push({ kind: 'kv', label: 'Head line', value: input.palm.headLine });
  lines.push({ kind: 'kv', label: 'Fate line', value: input.palm.fateLine });
  lines.push({ kind: 'spacer', height: 8 });
  lines.push({ kind: 'heading', text: copy.reading });
  lines.push({ kind: 'subheading', text: 'Overview' });
  lines.push({ kind: 'body', text: input.reading.overview });
  lines.push({ kind: 'subheading', text: 'Personality' });
  lines.push({ kind: 'body', text: input.reading.personality });
  lines.push({ kind: 'subheading', text: 'Career' });
  lines.push({ kind: 'body', text: input.reading.career });
  lines.push({ kind: 'subheading', text: 'Health' });
  lines.push({ kind: 'body', text: input.reading.health });
  lines.push({ kind: 'subheading', text: 'Relationships' });
  lines.push({ kind: 'body', text: input.reading.relationships });
  lines.push({ kind: 'subheading', text: 'Period' });
  lines.push({ kind: 'body', text: input.reading.period });

  return premiumReport({
    title: input.subject.name,
    subtitle: 'Palm reading',
    bandLabel: 'Palm',
    lines,
    disclaimer: input.disclaimer ?? ASTROLOGY_DISCLAIMER,
    footer: copy.footer,
  });
}

export type TodayPrintPdfInput = {
  subject: ReadingSubject;
  asOf: string;
  panchang: Record<string, string | undefined>;
  dasha: { label: string; levels: string[] };
  accuracyNote?: string;
  insightBullets?: string[];
  locale?: 'en' | 'hi';
  disclaimer?: string;
};

export async function buildTodayReportPdf(input: TodayPrintPdfInput): Promise<Buffer> {
  const locale = pdfLocale(input.locale);
  const hi = locale === 'hi';
  const copy = kundaliPdfCopy(locale);
  const lines: ReportLine[] = [
    ...personLines(input.subject, locale, hi ? 'जन्म विवरण' : 'Birth details'),
    { kind: 'spacer', height: 8 },
    { kind: 'kv', label: hi ? 'समय' : 'As of', value: input.asOf },
    { kind: 'spacer', height: 8 },
    { kind: 'heading', text: hi ? 'पंचांग' : 'Panchang' },
  ];

  const labels: Array<[string, string, string]> = [
    ['weekday', 'Weekday', 'वार'],
    ['tithi', 'Tithi', 'तिथि'],
    ['nakshatra', 'Nakshatra', 'नक्षत्र'],
    ['yoga', 'Yoga', 'योग'],
    ['karana', 'Karana', 'करण'],
    ['lunarMonth', 'Lunar month', 'चंद्र मास'],
    ['sunrise', 'Sunrise', 'सूर्योदय'],
    ['sunset', 'Sunset', 'सूर्यास्त'],
    ['horaLord', 'Hora lord', 'होरा स्वामी'],
    ['dishaShool', 'Disha shool', 'दिशा शूल'],
  ];
  for (const [key, en, hindi] of labels) {
    const value = input.panchang[key];
    if (value) {
      lines.push({
        kind: 'kv',
        label: hi ? hindi : en,
        value: localizeChartValue(value, locale),
      });
    }
  }

  lines.push({ kind: 'spacer', height: 8 });
  lines.push({ kind: 'heading', text: hi ? 'वर्तमान दशा' : 'Current dasha' });
  lines.push({
    kind: 'kv',
    label: hi ? 'अवधि' : 'Period',
    value: localizeChartValue(input.dasha.label || '-', locale),
  });
  for (const level of input.dasha.levels) {
    lines.push({ kind: 'body', text: `- ${localizeChartValue(level, locale)}` });
  }

  lines.push(...insightLines(input.insightBullets, copy.reading));

  if (input.accuracyNote) {
    lines.push({ kind: 'spacer', height: 8 });
    lines.push({ kind: 'muted', text: input.accuracyNote });
  }

  return premiumReport({
    title: input.subject.name,
    subtitle: hi ? 'दैनिक काल' : 'Daily periods',
    bandLabel: hi ? 'आज' : 'Today',
    lines,
    disclaimer: hi ? copy.disclaimer : (input.disclaimer ?? ASTROLOGY_DISCLAIMER),
    footer: copy.footer,
  });
}
