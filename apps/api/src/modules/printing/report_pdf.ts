import './fontkit_runtime.js';
import fontkit from '@pdf-lib/fontkit/dist/fontkit.es.js';
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
      frame?: boolean;
    };

export type ReportPdfFontBytes = {
  regular: Uint8Array;
  bold: Uint8Array;
};

export type BuildReportPdfInput = {
  title: string;
  subtitle?: string;
  lines: ReportLine[];
  disclaimer?: string;
  generatedAt?: Date;
  fonts?: ReportPdfFontBytes;
  /** Keep Devanagari and other non-ASCII glyphs. Requires [fonts]. */
  preserveUnicode?: boolean;
  /** Indigo band, gold rule, and the name set as the title. */
  premiumHeader?: boolean;
  /** Small line under ATHENA inside the premium band. */
  bandLabel?: string;
  footer?: string;
};

/** Helvetica/WinAnsi cannot encode many Unicode glyphs — normalize for print. */
export function sanitizePdfText(text: string): string {
  return text
    .replace(/\u2082/g, '2') // ₂
    .replace(/\u00b0/g, ' deg') // °
    .replace(/[–—]/g, '-')
    .replace(/\u00b7/g, '|') // · middle dot
    .replace(/•/g, '-')
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/\u2026/g, '...')
    .replace(/[^\x09\x0A\x0D\x20-\x7E]/g, '?');
}

function preparePdfText(text: string, preserveUnicode: boolean): string {
  const source = preserveUnicode ? text : sanitizePdfText(text);
  return source.replace(/\s+/g, ' ').trim();
}

function wrapText(
  text: string,
  font: PDFFont,
  size: number,
  maxWidth: number,
  preserveUnicode = false,
): string[] {
  const normalized = preparePdfText(text, preserveUnicode);
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
  if (input.fonts) {
    doc.registerFontkit(fontkit as Parameters<PDFDocument['registerFontkit']>[0]);
  }
  const preserveUnicode = input.preserveUnicode === true && input.fonts != null;
  const regular = input.fonts
    ? await doc.embedFont(input.fonts.regular, { subset: true })
    : await doc.embedFont(StandardFonts.Helvetica);
  const bold = input.fonts
    ? await doc.embedFont(input.fonts.bold, { subset: true })
    : await doc.embedFont(StandardFonts.HelveticaBold);
  const generatedAt = input.generatedAt ?? new Date();
  const timestamp = generatedAt.toISOString().replace('T', ' ').slice(0, 19) + ' UTC';
  const premium = input.premiumHeader === true;
  const bandHeight = 78;

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
    const rows = wrapText(text, font, size, CONTENT_WIDTH, preserveUnicode);
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

  if (premium) {
    page.drawRectangle({
      x: 0,
      y: PAGE_HEIGHT - bandHeight,
      width: PAGE_WIDTH,
      height: bandHeight,
      color: rgb(0.11, 0.07, 0.27),
    });
    page.drawRectangle({
      x: 0,
      y: PAGE_HEIGHT - bandHeight - 3,
      width: PAGE_WIDTH,
      height: 3,
      color: rgb(0.79, 0.6, 0.22),
    });
    page.drawText('ATHENA', {
      x: MARGIN,
      y: PAGE_HEIGHT - 34,
      size: 13,
      font: bold,
      color: rgb(1, 1, 1),
    });
    page.drawText(preparePdfText(input.bandLabel ?? 'Kundali', preserveUnicode), {
      x: MARGIN,
      y: PAGE_HEIGHT - 54,
      size: 11,
      font: regular,
      color: rgb(0.9, 0.84, 0.62),
    });
    y = PAGE_HEIGHT - bandHeight - 28;
    drawWrapped(input.title, bold, 22);
    if (input.subtitle) {
      y -= 2;
      drawWrapped(input.subtitle, regular, 12, rgb(0.35, 0.32, 0.48));
    }
    y -= 8;
  } else {
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
  }

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
        const label = preparePdfText(`${line.label}: `, preserveUnicode);
        const labelWidth = bold.widthOfTextAtSize(label, 11);
        const valueRows = wrapText(
          line.value || '-',
          regular,
          11,
          Math.max(40, CONTENT_WIDTH - labelWidth),
          preserveUnicode,
        );
        ensureSpace(11 + LINE_GAP);
        page.drawText(label, {
          x: MARGIN,
          y: y - 11,
          size: 11,
          font: bold,
          color: rgb(0.12, 0.14, 0.18),
        });
        page.drawText(valueRows[0] ?? '-', {
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
        const maxW = CONTENT_WIDTH - (line.frame ? 16 : 0);
        const maxH = line.maxHeight ?? 360;
        const scale = Math.min(maxW / embedded.width, maxH / embedded.height, 1);
        const w = embedded.width * scale;
        const h = embedded.height * scale;
        const pad = line.frame ? 8 : 0;
        ensureSpace(h + pad * 2 + (line.caption ? 28 : 12));
        const imageX = MARGIN + (CONTENT_WIDTH - w) / 2;
        if (line.frame) {
          page.drawRectangle({
            x: imageX - pad,
            y: y - h - pad,
            width: w + pad * 2,
            height: h + pad * 2,
            color: rgb(0.98, 0.97, 0.99),
            borderColor: rgb(0.78, 0.74, 0.88),
            borderWidth: 1,
          });
        }
        page.drawImage(embedded, {
          x: imageX,
          y: y - h,
          width: w,
          height: h,
        });
        y -= h + pad + 6;
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
    const footer = preparePdfText(
      input.footer ?? 'Printed at ATHENA kiosk | For personal reference only',
      preserveUnicode,
    );
    p.drawText(footer, {
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
