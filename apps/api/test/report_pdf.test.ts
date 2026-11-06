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

function cmapChar(hex: string): string {
  const buf = Buffer.from(hex, 'hex');
  if (buf.length < 2) return buf.toString('latin1');
  let out = '';
  for (let i = 0; i + 1 < buf.length; i += 2) {
    out += String.fromCharCode((buf[i] << 8) | buf[i + 1]);
  }
  return out;
}

function parseToUnicode(content: string): Map<number, string> {
  const map = new Map<number, string>();
  for (const line of content.split(/\r?\n/)) {
    const range = line.match(/<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>/);
    if (range) {
      const start = parseInt(range[1], 16);
      const end = parseInt(range[2], 16);
      const first = parseInt(range[3], 16);
      if (end >= start && end - start < 10000) {
        for (let id = start; id <= end; id += 1) {
          map.set(id, String.fromCodePoint(first + (id - start)));
        }
      }
      continue;
    }
    const pair = line.match(/<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>/);
    if (pair) {
      map.set(parseInt(pair[1], 16), cmapChar(pair[2]));
    }
  }
  return map;
}

/** Inflate PDF streams and recover drawn text, including subset custom fonts. */
function pdfDrawnText(bytes: Uint8Array): string {
  const raw = Buffer.from(bytes).toString('latin1');
  const streams: string[] = [];
  const re = /\/Length\s+(\d+)\s*>>\s*stream\r?\n/g;
  for (const match of raw.matchAll(re)) {
    const start = (match.index ?? 0) + match[0].length;
    const body = Buffer.from(raw.slice(start, start + Number(match[1])), 'latin1');
    try {
      streams.push(inflateSync(body).toString('latin1'));
    } catch {
      streams.push(body.toString('latin1'));
    }
  }
  const maps = streams
    .filter((stream) => stream.includes('beginbfchar') || stream.includes('beginbfrange'))
    .map(parseToUnicode)
    .filter((map) => map.size > 0);
  const draws: string[] = [];
  for (const stream of streams) {
    for (const hexMatch of stream.matchAll(/<([0-9A-Fa-f]+)>\s*Tj/g)) {
      const hex = hexMatch[1];
      if (maps.length > 0 && hex.length % 4 === 0) {
        for (const map of maps) {
          let text = '';
          for (let i = 0; i < hex.length; i += 4) {
            text += map.get(parseInt(hex.slice(i, i + 4), 16)) ?? '';
          }
          if (text.trim()) draws.push(text);
        }
      }
      draws.push(Buffer.from(hex, 'hex').toString('latin1'));
    }
  }
  return draws.join('\n');
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
    expect(drawn).toContain('Reading');
    expect(drawn).not.toContain('AI insights');
    expect(drawn).toContain(' | ');
    expect(drawn.includes('?')).toBe(false);
  });

  it('builds a Hindi kundali PDF in the selected language', async () => {
    const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"><rect width="200" height="200" fill="#f5e6c8"/></svg>';
    const bytes = await buildKundaliReportPdf({
      subject,
      style: 'north',
      chart: { lagna: 'Aries', sunSign: 'Pisces' },
      charts: [{ key: 'RasiD1', title: 'Birth', subtitle: 'Rasi', svg }],
      insights: [
        {
          key: 'RasiD1',
          title: 'Birth',
          bullets: ['स्थिर विकास और स्पष्ट आदतें।'],
        },
      ],
      locale: 'hi',
    });
    expect(bytes.subarray(0, 4).toString()).toBe('%PDF');
    const drawn = pdfDrawnText(bytes);
    expect(drawn).toContain('जन्म');
    expect(drawn).toContain('लग्न मेष');
    expect(drawn).toContain('उत्तर भारतीय');
    expect(drawn).toContain('आदत');
    expect(drawn).not.toContain('AI insights');
    expect(drawn).not.toContain('Reading');
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
    expect(pdfDrawnText(matchBytes)).toContain('Gun Milan score');

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
    const palmDrawn = pdfDrawnText(palmBytes);
    expect(palmDrawn).toContain('Palm lines');
    expect(palmDrawn).toContain('Reading');
    expect(palmDrawn).not.toContain('AI insights');

    const todayBytes = await buildTodayReportPdf({
      subject,
      asOf: new Date().toISOString(),
      panchang: { weekday: 'Tuesday', tithi: 'Shukla Paksha' },
      dasha: { label: 'Rahu – Saturn', levels: ['Rahu', 'Saturn'] },
    });
    expect(todayBytes.subarray(0, 4).toString()).toBe('%PDF');
    expect(pdfDrawnText(todayBytes)).toContain('Panchang');

    const hindiMatch = await buildMatchReportPdf({
      groom: { ...subject, name: 'Arjun', gender: 'male' },
      bride: subject,
      score: { total: 28, max: 36, summary: 'Strong match', tone: 'good' },
      kutas: [{ name: 'Varna', maxPoints: 1, points: 1, verdict: 'Good' }],
      insightBullets: ['खुलकर बात करें'],
      locale: 'hi',
    });
    const hindiDrawn = pdfDrawnText(hindiMatch);
    expect(hindiDrawn).toContain('अंक');
    expect(hindiDrawn).toContain('अच्छा');
    expect(hindiDrawn).toContain('वर');
    expect(hindiDrawn).toContain('कूट');
    expect(hindiDrawn).not.toContain('AI insights');

    const hindiToday = await buildTodayReportPdf({
      subject,
      asOf: '2026-11-06',
      panchang: { tithi: 'Shukla', nakshatra: 'Rohini' },
      dasha: { label: 'Rahu', levels: ['Saturn'] },
      insightBullets: ['आज धैर्य रखें'],
      locale: 'hi',
    });
    const todayDrawn = pdfDrawnText(hindiToday);
    expect(todayDrawn).toContain('पंचांग');
    expect(todayDrawn).toContain('राहु');
    expect(todayDrawn).not.toContain('AI insights');
  });
});
