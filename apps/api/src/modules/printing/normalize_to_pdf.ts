import { PDFDocument } from 'pdf-lib';
import { loadConfig } from '../../config/index.js';
import { AppError } from '../../shared/errors.js';
import { docxToPdf, type DocxConvertOptions } from './docx_to_pdf.js';
import { countPdfPages } from './report_pdf.js';

const PAGE_WIDTH = 595.28;
const PAGE_HEIGHT = 841.89;
const MARGIN = 36;

export type NormalizeToPdfInput = {
  bytes: Buffer | Uint8Array;
  mimeType?: string | null;
  fileName?: string | null;
  /** Override LibreOffice settings / inject execFile (tests). */
  docx?: DocxConvertOptions;
};

export type NormalizeToPdfResult = {
  pdfBytes: Buffer;
  pageCount: number;
  contentType: 'application/pdf';
};

type DetectedKind = 'pdf' | 'jpeg' | 'png' | 'docx';

function extensionOf(fileName?: string | null): string {
  if (!fileName) return '';
  const base = fileName.split(/[/\\]/).pop() ?? fileName;
  const dot = base.lastIndexOf('.');
  if (dot < 0) return '';
  return base.slice(dot + 1).toLowerCase();
}

function looksLikeDocxMime(mime: string): boolean {
  return (
    mime.includes('wordprocessingml') ||
    mime === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
    mime.includes('application/docx')
  );
}

function isZipMagic(buf: Buffer): boolean {
  return buf.length >= 4 && buf[0] === 0x50 && buf[1] === 0x4b;
}

function detectKind(
  bytes: Buffer | Uint8Array,
  mimeType?: string | null,
  fileName?: string | null,
): DetectedKind | null {
  const buf = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes);
  const mime = (mimeType ?? '').toLowerCase();
  const ext = extensionOf(fileName);

  if (buf.length >= 5 && buf.subarray(0, 5).toString('ascii') === '%PDF-') {
    return 'pdf';
  }
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) {
    return 'jpeg';
  }
  if (
    buf.length >= 8 &&
    buf[0] === 0x89 &&
    buf[1] === 0x50 &&
    buf[2] === 0x4e &&
    buf[3] === 0x47
  ) {
    return 'png';
  }

  // DOCX is a ZIP; require extension or Word mime so arbitrary ZIPs are rejected.
  if (isZipMagic(buf) && (ext === 'docx' || looksLikeDocxMime(mime))) {
    return 'docx';
  }

  if (mime.includes('pdf') || ext === 'pdf') return 'pdf';
  if (mime.includes('jpeg') || mime === 'image/jpg' || ext === 'jpg' || ext === 'jpeg') {
    return 'jpeg';
  }
  if (mime.includes('png') || ext === 'png') return 'png';
  if (ext === 'docx' || looksLikeDocxMime(mime)) return 'docx';

  return null;
}

/** pdf-lib DataView reads ignore Buffer byteOffset — copy to a clean view. */
function asStandaloneBytes(bytes: Buffer | Uint8Array): Uint8Array {
  return Uint8Array.from(Buffer.from(bytes));
}

async function imageToPdf(bytes: Buffer | Uint8Array, kind: 'jpeg' | 'png'): Promise<Buffer> {
  const doc = await PDFDocument.create();
  const imageBytes = asStandaloneBytes(bytes);
  const embedded =
    kind === 'jpeg' ? await doc.embedJpg(imageBytes) : await doc.embedPng(imageBytes);
  const page = doc.addPage([PAGE_WIDTH, PAGE_HEIGHT]);
  const maxW = PAGE_WIDTH - MARGIN * 2;
  const maxH = PAGE_HEIGHT - MARGIN * 2;
  const scale = Math.min(maxW / embedded.width, maxH / embedded.height, 1);
  const drawW = embedded.width * scale;
  const drawH = embedded.height * scale;
  const x = (PAGE_WIDTH - drawW) / 2;
  const y = (PAGE_HEIGHT - drawH) / 2;
  page.drawImage(embedded, { x, y, width: drawW, height: drawH });
  return Buffer.from(await doc.save());
}

function resolveDocxOptions(override?: DocxConvertOptions): DocxConvertOptions {
  if (override) {
    return override;
  }
  const cfg = loadConfig().libreOffice;
  return {
    bin: cfg.bin,
    timeoutMs: cfg.timeoutMs,
    maxConcurrent: cfg.maxConcurrent,
  };
}

/**
 * Normalize citizen / DigiLocker payloads to PDF for the shared print pipeline.
 * Supports PDF pass-through, JPEG/PNG → single A4 page, and DOCX via LibreOffice.
 */
export async function normalizeToPdf(input: NormalizeToPdfInput): Promise<NormalizeToPdfResult> {
  const bytes = input.bytes;
  if (!bytes || bytes.length === 0) {
    throw new AppError('invalid_file_type', 'Empty file', 400);
  }

  const kind = detectKind(bytes, input.mimeType, input.fileName);
  if (!kind) {
    throw new AppError(
      'unsupported_format',
      'Only PDF, image files (JPG/PNG), or Word (.docx) can be printed',
      400,
    );
  }

  let pdfBytes: Buffer;
  if (kind === 'pdf') {
    pdfBytes = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes);
  } else if (kind === 'docx') {
    pdfBytes = await docxToPdf(bytes, resolveDocxOptions(input.docx));
  } else {
    try {
      pdfBytes = await imageToPdf(bytes, kind);
    } catch {
      throw new AppError(
        'invalid_file_type',
        `Could not convert image to PDF${input.fileName ? `: ${input.fileName}` : ''}`,
        400,
      );
    }
  }

  let pageCount: number;
  try {
    pageCount = await countPdfPages(pdfBytes);
  } catch {
    throw new AppError(
      'invalid_pdf',
      `Could not read PDF${input.fileName ? `: ${input.fileName}` : ''}`,
      400,
    );
  }
  if (pageCount < 1) {
    throw new AppError(
      'invalid_pdf',
      `PDF has no pages${input.fileName ? `: ${input.fileName}` : ''}`,
      400,
    );
  }

  return {
    pdfBytes,
    pageCount,
    contentType: 'application/pdf',
  };
}

/** True if MIME/extension looks like an accepted upload type (before magic-byte check). */
export function isAcceptedPrintUpload(mimeType?: string | null, fileName?: string | null): boolean {
  const mime = (mimeType ?? '').toLowerCase();
  const ext = extensionOf(fileName);
  if (mime.includes('pdf') || ext === 'pdf') return true;
  if (mime.includes('jpeg') || mime === 'image/jpg' || ext === 'jpg' || ext === 'jpeg') {
    return true;
  }
  if (mime.includes('png') || ext === 'png') return true;
  if (ext === 'docx' || looksLikeDocxMime(mime)) return true;
  return false;
}
