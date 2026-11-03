import { inflateSync } from 'node:zlib';
import { describe, expect, it } from 'vitest';
import { PDFDocument } from 'pdf-lib';
import {
  buildReportPdf,
  countPdfPages,
  sanitizePdfText,
  svgToPng,
} from '../src/modules/printing/report_pdf.js';
import { buildHealthReportPdf } from '../src/modules/well_being/well_being_report_pdf.js';
import {
  buildKundaliReportPdf,
  buildMatchReportPdf,
  buildPalmReportPdf,
  buildTodayReportPdf,
} from '../src/modules/astrology/astrology_report_pdf.js';

/** Inflate FlateDecode streams and decode hex `<...> Tj` text (pdf-lib Helvetica). */
function pdfDrawnText(bytes: Uint8Array): string {
  const raw = Buffer.from(bytes).toString('latin1');
  const parts: string[] = [];
  const re = /stream\r?\n([\s\S]*?)\r?\nendstream/g;
  for (const match of raw.matchAll(re)) {
    let content: string;
    try {
      content = inflateSync(Buffer.from(match[1], 'latin1')).toString('latin1');
    } catch {
      continue;
    }
    for (const hexMatch of content.matchAll(/<([0-9A-Fa-f]+)>\s*Tj/g)) {
      parts.push(Buffer.from(hexMatch[1], 'hex').toString('latin1'));
    }
  }
  return parts.join('\n');
}

const subject = {
  name: 'Asha',
  gender: 'female' as const,
  dateOfBirth: '1992-03-18',
  birthTime: '12:00',
  birthPlace: 'Jaipur',
  birthTimeUnknown: true,
};

describe('sanitizePdfText', () => {
  it('maps middle dots and bullets to ASCII instead of question marks', () => {
    expect(sanitizePdfText('A · B')).toBe('A | B');
    expect(sanitizePdfText('• tip')).toBe('- tip');
    expect(sanitizePdfText('Kundali — Asha')).toBe('Kundali - Asha');
  });

  it('still replaces unsupported scripts with question marks', () => {
    expect(sanitizePdfText('नमस्ते')).toMatch(/^\?+$/);
  });
});

describe('report PDF builders', () => {
  it('builds a multi-line ATHENA report PDF', async () => {
    const bytes = await buildReportPdf({
      title: 'Sample Report',
      subtitle: 'Unit test',
      lines: [
        { kind: 'heading', text: 'Section' },
        { kind: 'kv', label: 'Name', value: 'Asha' },
        { kind: 'body', text: 'Hello world from the kiosk report builder.' },
      ],
      disclaimer: 'For testing only.',
    });
    expect(bytes.subarray(0, 4).toString()).toBe('%PDF');
    expect(await countPdfPages(bytes)).toBeGreaterThanOrEqual(1);
  });

  it('builds a health report for oxi mode', async () => {
    const bytes = await buildHealthReportPdf({
      mode: 'oxi',
      heartRate: 72,
      spo2: 98,
      heartRateInterpretation: 'Normal Heart Rate',
      spo2Interpretation: 'Excellent Oxygen Saturation',
    });
    expect(bytes.subarray(0, 4).toString()).toBe('%PDF');
  });

  it('builds a health report for temp mode', async () => {
    const bytes = await buildHealthReportPdf({
      mode: 'temp',
      tempC: 36.8,
      tempF: 98.2,
      temperatureInterpretation: 'Normal Range',
    });
    expect(bytes.subarray(0, 4).toString()).toBe('%PDF');
  });

  it('rasterizes SVG text with system fonts and builds a one-page kundali PDF', async () => {
    const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"><rect width="200" height="200" fill="#f5e6c8"/><text x="20" y="100" font-size="28">Mars</text></svg>';
    const png = svgToPng(svg, 200);
    expect(png[0]).toBe(0x89);
    expect(png[1]).toBe(0x50);
    // Text glyphs should make the PNG larger than a blank frame of the same size.
    expect(png.length).toBeGreaterThan(800);

    const bytes = await buildKundaliReportPdf({
      subject,
      style: 'north',
      chart: { lagna: 'Aries', sunSign: 'Pisces' },
      charts: [{ key: 'RasiD1', title: 'Birth', subtitle: 'Rasi', svg }],
      insights: [
        {
          key: 'RasiD1',
          title: 'Birth',
          bullets: ['Steady growth', 'Clear habits', 'Finish started work'],
        },
      ],
      locale: 'en',
    });
    expect(bytes.subarray(0, 4).toString()).toBe('%PDF');
    const doc = await PDFDocument.load(bytes);
    expect(doc.getPageCount()).toBe(1);

    const drawn = pdfDrawnText(bytes);
    expect(drawn).toContain('Steady growth');
    expect(drawn).toContain('AI insights');
    expect(drawn).toContain(' | ');
    expect(drawn).not.toContain('AI insights (HI)');
    expect(drawn.includes('?')).toBe(false);
  });

  it('builds match, palm, and today report PDFs', async () => {
    const matchBytes = await buildMatchReportPdf({
      groom: { ...subject, name: 'Arjun', gender: 'male' },
      bride: subject,
      score: { total: 28, max: 36, summary: 'Strong match', tone: 'good' },
      kutas: [
        { name: 'Varna', maxPoints: 1, points: 1, nature: 'Friendly', verdict: 'Good' },
      ],
    });
    expect(matchBytes.subarray(0, 4).toString()).toBe('%PDF');

    const palmBytes = await buildPalmReportPdf({
      subject,
      chart: { moonSign: 'Taurus' },
      palm: {
        summary: 'Clear lines',
        lifeLine: 'Long',
        heartLine: 'Warm',
        headLine: 'Focused',
        fateLine: 'Steady',
      },
      reading: {
        overview: 'Overview',
        personality: 'Personality',
        career: 'Career',
        health: 'Health',
        relationships: 'Relationships',
        period: 'Period',
      },
    });
    expect(palmBytes.subarray(0, 4).toString()).toBe('%PDF');

    const todayBytes = await buildTodayReportPdf({
      subject,
      asOf: new Date().toISOString(),
      panchang: { weekday: 'Tuesday', tithi: 'Shukla Paksha' },
      dasha: { label: 'Rahu – Saturn', levels: ['Rahu', 'Saturn'] },
    });
    expect(todayBytes.subarray(0, 4).toString()).toBe('%PDF');
  });
});
