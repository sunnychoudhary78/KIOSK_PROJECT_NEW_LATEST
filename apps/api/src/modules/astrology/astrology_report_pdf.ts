import { buildReportPdf, svgToPng, type ReportLine } from '../printing/report_pdf.js';
import { ASTROLOGY_DISCLAIMER, type ChartSummary, type ReadingSubject } from './astrology.schemas.js';

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
  const primary = input.charts[0];
  const singleChart = input.charts.length === 1;
  const hasInsights = (input.insights ?? []).some((section) => section.bullets.length > 0);
  // Keep single-chart reports on one A4 page (header + meta + chart + bullets).
  const chartMaxHeight = singleChart ? (hasInsights ? 300 : 380) : 380;

  const lines: ReportLine[] = [];

  if (singleChart) {
    lines.push({ kind: 'kv', label: 'Name', value: input.subject.name });
    lines.push({
      kind: 'kv',
      label: 'Birth',
      value: `${input.subject.dateOfBirth} | ${
        input.subject.birthTimeUnknown
          ? `${input.subject.birthTime} (approx.)`
          : input.subject.birthTime
      } | ${input.subject.birthPlace}`,
    });
    lines.push({
      kind: 'kv',
      label: 'Style',
      value: input.style === 'south' ? 'South Indian' : 'North Indian',
    });
    const summaryBits = [
      input.chart.lagna ? `Lagna ${input.chart.lagna}` : null,
      input.chart.sunSign ? `Sun ${input.chart.sunSign}` : null,
      input.chart.moonSign ? `Moon ${input.chart.moonSign}` : null,
      input.chart.nakshatra ? `Nakshatra ${input.chart.nakshatra}` : null,
      input.chart.currentDasha ? `Dasha ${input.chart.currentDasha}` : null,
    ].filter(Boolean);
    if (summaryBits.length > 0) {
      lines.push({ kind: 'kv', label: 'Chart', value: summaryBits.join(' | ') });
    }
    lines.push({ kind: 'spacer', height: 4 });
    if (primary) {
      lines.push({ kind: 'heading', text: `${primary.title} | ${primary.subtitle}` });
    }
  } else {
    lines.push(...subjectLines(input.subject));
    lines.push({ kind: 'spacer', height: 4 });
    lines.push({
      kind: 'kv',
      label: 'Style',
      value: input.style === 'south' ? 'South Indian' : 'North Indian',
    });
    lines.push({ kind: 'spacer', height: 4 });
    lines.push(...chartSummaryLines(input.chart));
    lines.push({ kind: 'spacer', height: 6 });
    lines.push({ kind: 'heading', text: 'Charts' });
  }

  for (const chart of input.charts) {
    try {
      const png = svgToPng(chart.svg, singleChart ? 1100 : 1000);
      if (!singleChart) {
        lines.push({ kind: 'subheading', text: `${chart.title} | ${chart.subtitle}` });
      }
      lines.push({
        kind: 'image',
        bytes: png,
        format: 'png',
        maxHeight: chartMaxHeight,
      });
    } catch {
      lines.push({
        kind: 'muted',
        text: `Chart ${chart.title} (${chart.key}) could not be rendered for print.`,
      });
    }
  }

  if (hasInsights) {
    // Print always uses English bullets (Helvetica/WinAnsi); ignore locale for heading.
    const insightHeading = 'AI insights';
    if (singleChart) {
      const bullets = (input.insights ?? []).flatMap((section) => section.bullets);
      lines.push(...insightLines(bullets, insightHeading));
    } else {
      lines.push({ kind: 'spacer', height: 8 });
      lines.push({ kind: 'heading', text: insightHeading });
      for (const section of input.insights ?? []) {
        if (section.bullets.length === 0) continue;
        lines.push({ kind: 'subheading', text: section.title });
        for (const bullet of section.bullets) {
          lines.push({ kind: 'body', text: `- ${bullet}` });
        }
      }
    }
  }

  const subtitle = primary ? `${primary.title} chart report` : 'Birth chart report';

  return buildReportPdf({
    title: `Kundali - ${input.subject.name}`,
    subtitle,
    lines,
    disclaimer: input.disclaimer ?? ASTROLOGY_DISCLAIMER,
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
  const lines: ReportLine[] = [
    ...subjectLines(input.groom, 'Groom'),
    { kind: 'spacer', height: 8 },
    ...subjectLines(input.bride, 'Bride'),
    { kind: 'spacer', height: 10 },
    { kind: 'heading', text: 'Gun Milan score' },
    {
      kind: 'kv',
      label: 'Score',
      value: `${input.score.total} / ${input.score.max} (${input.score.tone})`,
    },
    { kind: 'body', text: input.score.summary },
    { kind: 'spacer', height: 8 },
    { kind: 'heading', text: 'Kutas' },
  ];

  for (const kuta of input.kutas) {
    const points = kuta.points == null ? '-' : String(kuta.points);
    lines.push({
      kind: 'kv',
      label: kuta.name,
      value: `${points} / ${kuta.maxPoints}${kuta.verdict ? ` | ${kuta.verdict}` : ''}${
        kuta.nature ? ` (${kuta.nature})` : ''
      }`,
    });
  }

  lines.push(...insightLines(input.insightBullets, 'AI insights'));

  if (input.accuracyNote) {
    lines.push({ kind: 'spacer', height: 8 });
    lines.push({ kind: 'muted', text: input.accuracyNote });
  }

  return buildReportPdf({
    title: `Match Kundali - ${input.groom.name} & ${input.bride.name}`,
    subtitle: 'Compatibility report',
    lines,
    disclaimer: input.disclaimer ?? ASTROLOGY_DISCLAIMER,
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
  const lines: ReportLine[] = [
    ...subjectLines(input.subject),
    { kind: 'spacer', height: 8 },
    ...chartSummaryLines(input.chart),
    { kind: 'spacer', height: 8 },
  ];

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
        });
      }
    } catch {
      // Ignore invalid palm image for print.
    }
  }

  lines.push({ kind: 'heading', text: 'Palm insights' });
  lines.push({ kind: 'body', text: input.palm.summary });
  lines.push({ kind: 'kv', label: 'Life line', value: input.palm.lifeLine });
  lines.push({ kind: 'kv', label: 'Heart line', value: input.palm.heartLine });
  lines.push({ kind: 'kv', label: 'Head line', value: input.palm.headLine });
  lines.push({ kind: 'kv', label: 'Fate line', value: input.palm.fateLine });
  lines.push({ kind: 'spacer', height: 8 });
  lines.push({ kind: 'heading', text: 'Reading' });
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

  return buildReportPdf({
    title: `Palm Reading - ${input.subject.name}`,
    subtitle: 'Palm insights report',
    lines,
    disclaimer: input.disclaimer ?? ASTROLOGY_DISCLAIMER,
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
  const lines: ReportLine[] = [
    ...subjectLines(input.subject),
    { kind: 'spacer', height: 8 },
    { kind: 'kv', label: 'As of', value: input.asOf },
    { kind: 'spacer', height: 8 },
    { kind: 'heading', text: 'Panchang' },
  ];

  const labels: Array<[string, string]> = [
    ['weekday', 'Weekday'],
    ['tithi', 'Tithi'],
    ['nakshatra', 'Nakshatra'],
    ['yoga', 'Yoga'],
    ['karana', 'Karana'],
    ['lunarMonth', 'Lunar month'],
    ['sunrise', 'Sunrise'],
    ['sunset', 'Sunset'],
    ['horaLord', 'Hora lord'],
    ['dishaShool', 'Disha shool'],
  ];
  for (const [key, label] of labels) {
    const value = input.panchang[key];
    if (value) lines.push({ kind: 'kv', label, value });
  }

  lines.push({ kind: 'spacer', height: 8 });
  lines.push({ kind: 'heading', text: 'Current dasha' });
  lines.push({ kind: 'kv', label: 'Period', value: input.dasha.label || '-' });
  for (const level of input.dasha.levels) {
    lines.push({ kind: 'body', text: `- ${level}` });
  }

  lines.push(...insightLines(input.insightBullets, 'AI insights'));

  if (input.accuracyNote) {
    lines.push({ kind: 'spacer', height: 8 });
    lines.push({ kind: 'muted', text: input.accuracyNote });
  }

  return buildReportPdf({
    title: `Today & Panchang - ${input.subject.name}`,
    subtitle: 'Daily periods report',
    lines,
    disclaimer: input.disclaimer ?? ASTROLOGY_DISCLAIMER,
  });
}
