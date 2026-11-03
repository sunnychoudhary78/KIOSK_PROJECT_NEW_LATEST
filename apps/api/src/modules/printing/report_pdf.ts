import { PDFDocument, StandardFonts, rgb, type PDFFont, type PDFPage } from 'pdf-lib';
import { Resvg } from '@resvg/resvg-js';

const PAGE_WIDTH = 595.28;
const PAGE_HEIGHT = 841.89;
const MARGIN = 48;
const CONTENT_WIDTH = PAGE_WIDTH - MARGIN * 2;
const LINE_GAP = 4;
const FOOTER_RESERVE = 56;

export type ReportLine =
  | { kind: 'heading'; text: string }
  | { kind: 'subheading'; text: string }
  | { kind: 'body'; text: string }
  | { kind: 'muted'; text: string }
  | { kind: 'spacer'; height?: number }
  | { kind: 'kv'; label: string; value: string }
  | {
      kind: 'image';
      bytes: Uint8Array;
      format?: 'png' | 'jpg';
      caption?: string;
      maxHeight?: number;
    };

export type BuildReportPdfInput = {
  title: string;
  subtitle?: string;
  lines: ReportLine[];
  disclaimer?: string;
  generatedAt?: Date;
};

/** Helvetica/WinAnsi cannot encode many Unicode glyphs — normalize for print. */
export function sanitizePdfText(text: string): string {
  return text
    .replace(/\u2082/g, '2') // ₂
    .replace(/\u00b0/g, ' deg') // °
    .replace(/[–—]/g, '-')
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/\u2026/g, '...')
    .replace(/[^\x09\x0A\x0D\x20-\x7E]/g, '?');
}

function wrapText(text: string, font: PDFFont, size: number, maxWidth: number): string[] {
  const normalized = sanitizePdfText(text).replace(/\s+/g, ' ').trim();
  if (!normalized) return [''];
  const words = normalized.split(' ');
  const rows: string[] = [];
  let current = '';
  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (font.widthOfTextAtSize(candidate, size) <= maxWidth) {
      current = candidate;
      continue;
    }
    if (current) rows.push(current);
    if (font.widthOfTextAtSize(word, size) <= maxWidth) {
      current = word;
      continue;
    }
    // Hard-break very long tokens.
    let rest = word;
    while (rest.length > 0) {
      let cut = rest.length;
      while (cut > 1 && font.widthOfTextAtSize(rest.slice(0, cut), size) > maxWidth) {
        cut -= 1;
      }
      rows.push(rest.slice(0, cut));
      rest = rest.slice(cut);
    }
    current = '';
  }
  if (current) rows.push(current);
  return rows.length > 0 ? rows : [''];
}

export function svgToPng(svg: string, width = 900): Uint8Array {
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: width },
    // VedAstro chart labels need a real font; without this, text is blank.
    font: { loadSystemFonts: true },
  });
  return resvg.render().asPng();
}

export async function countPdfPages(buffer: Buffer | Uint8Array): Promise<number> {
  const doc = await PDFDocument.load(buffer, { ignoreEncryption: true });
  return doc.getPageCount();
}

export async function buildReportPdf(input: BuildReportPdfInput): Promise<Buffer> {
  const doc = await PDFDocument.create();
  const regular = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const generatedAt = input.generatedAt ?? new Date();
  const timestamp = generatedAt.toISOString().replace('T', ' ').slice(0, 19) + ' UTC';

  let page = doc.addPage([PAGE_WIDTH, PAGE_HEIGHT]);
  let y = PAGE_HEIGHT - MARGIN;

  const ensureSpace = (needed: number) => {
    if (y - needed >= MARGIN + FOOTER_RESERVE) return;
    page = doc.addPage([PAGE_WIDTH, PAGE_HEIGHT]);
    y = PAGE_HEIGHT - MARGIN;
  };

  const drawWrapped = (
    text: string,
    font: PDFFont,
    size: number,
    color = rgb(0.12, 0.14, 0.18),
  ) => {
    const rows = wrapText(text, font, size, CONTENT_WIDTH);
    for (const row of rows) {
      ensureSpace(size + LINE_GAP);
      page.drawText(row, {
        x: MARGIN,
        y: y - size,
        size,
        font,
        color,
      });
      y -= size + LINE_GAP;
    }
  };

  // Header
  drawWrapped('ATHENA Kiosk', bold, 11, rgb(0.35, 0.4, 0.48));
  y -= 6;
  drawWrapped(input.title, bold, 20);
  if (input.subtitle) {
    y -= 2;
    drawWrapped(input.subtitle, regular, 11, rgb(0.35, 0.4, 0.48));
  }
  y -= 2;
  drawWrapped(`Generated ${timestamp}`, regular, 9, rgb(0.45, 0.48, 0.52));
  y -= 10;
  page.drawLine({
    start: { x: MARGIN, y },
    end: { x: PAGE_WIDTH - MARGIN, y },
    thickness: 1,
    color: rgb(0.82, 0.84, 0.88),
  });
  y -= 16;

  for (const line of input.lines) {
    switch (line.kind) {
      case 'spacer':
        y -= line.height ?? 10;
        break;
      case 'heading':
        y -= 4;
        drawWrapped(line.text, bold, 14);
        y -= 4;
        break;
      case 'subheading':
        drawWrapped(line.text, bold, 12);
        y -= 2;
        break;
      case 'body':
        drawWrapped(line.text, regular, 11);
        break;
      case 'muted':
        drawWrapped(line.text, regular, 10, rgb(0.4, 0.44, 0.5));
        break;
      case 'kv': {
        const label = sanitizePdfText(`${line.label}: `);
        const labelWidth = bold.widthOfTextAtSize(label, 11);
        const valueRows = wrapText(line.value || '-', regular, 11, CONTENT_WIDTH - labelWidth);
        ensureSpace(11 + LINE_GAP);
        page.drawText(label, {
          x: MARGIN,
          y: y - 11,
          size: 11,
          font: bold,
          color: rgb(0.12, 0.14, 0.18),
        });
        page.drawText(valueRows[0] ?? '—', {
          x: MARGIN + labelWidth,
          y: y - 11,
          size: 11,
          font: regular,
          color: rgb(0.12, 0.14, 0.18),
        });
        y -= 11 + LINE_GAP;
        for (const row of valueRows.slice(1)) {
          ensureSpace(11 + LINE_GAP);
          page.drawText(row, {
            x: MARGIN + labelWidth,
            y: y - 11,
            size: 11,
            font: regular,
            color: rgb(0.12, 0.14, 0.18),
          });
          y -= 11 + LINE_GAP;
        }
        break;
      }
      case 'image': {
        const embedded =
          line.format === 'jpg'
            ? await doc.embedJpg(line.bytes)
            : await doc.embedPng(line.bytes);
        const maxW = CONTENT_WIDTH;
        const maxH = line.maxHeight ?? 360;
        const scale = Math.min(maxW / embedded.width, maxH / embedded.height, 1);
        const w = embedded.width * scale;
        const h = embedded.height * scale;
        ensureSpace(h + (line.caption ? 28 : 12));
        page.drawImage(embedded, {
          x: MARGIN + (CONTENT_WIDTH - w) / 2,
          y: y - h,
          width: w,
          height: h,
        });
        y -= h + 6;
        if (line.caption) {
          drawWrapped(line.caption, regular, 9, rgb(0.4, 0.44, 0.5));
        }
        y -= 8;
        break;
      }
      default:
        break;
    }
  }

  if (input.disclaimer) {
    y -= 8;
    drawWrapped(input.disclaimer, regular, 9, rgb(0.45, 0.48, 0.52));
  }

  // Footers on all pages
  const pages = doc.getPages();
  pages.forEach((p: PDFPage, index: number) => {
    p.drawLine({
      start: { x: MARGIN, y: MARGIN + 28 },
      end: { x: PAGE_WIDTH - MARGIN, y: MARGIN + 28 },
      thickness: 0.5,
      color: rgb(0.82, 0.84, 0.88),
    });
    p.drawText('Printed at ATHENA kiosk · For personal reference only', {
      x: MARGIN,
      y: MARGIN + 12,
      size: 8,
      font: regular,
      color: rgb(0.5, 0.52, 0.56),
    });
    const label = `Page ${index + 1} of ${pages.length}`;
    const width = regular.widthOfTextAtSize(label, 8);
    p.drawText(label, {
      x: PAGE_WIDTH - MARGIN - width,
      y: MARGIN + 12,
      size: 8,
      font: regular,
      color: rgb(0.5, 0.52, 0.56),
    });
  });

  return Buffer.from(await doc.save());
}
