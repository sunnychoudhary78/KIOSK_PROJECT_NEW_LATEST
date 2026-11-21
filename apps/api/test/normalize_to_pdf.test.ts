import { describe, expect, it } from 'vitest';
import { promises as fs } from 'node:fs';
import { PDFDocument } from 'pdf-lib';
import { isAppError } from '../src/shared/errors.js';
import type { DocxExecFile } from '../src/modules/printing/docx_to_pdf.js';
import {
  isAcceptedPrintUpload,
  normalizeToPdf,
} from '../src/modules/printing/normalize_to_pdf.js';

/** Small valid JPEG (8×8) accepted by pdf-lib embedJpg. */
const TINY_JPEG = Buffer.from(
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAIAAgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDi6KKK+ZP3E//Z',
  'base64',
);

/** Minimal valid 1×1 PNG. */
const TINY_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64',
);

/** Minimal ZIP magic + .docx name so detectKind accepts DOCX without a real OOXML package. */
const FAKE_DOCX = Buffer.concat([Buffer.from('PK\x03\x04'), Buffer.alloc(32, 1)]);

describe('isAcceptedPrintUpload', () => {
  it('accepts pdf jpg png docx by mime or extension', () => {
    expect(isAcceptedPrintUpload('application/pdf', 'a.bin')).toBe(true);
    expect(isAcceptedPrintUpload('image/jpeg', null)).toBe(true);
    expect(isAcceptedPrintUpload('image/png', null)).toBe(true);
    expect(isAcceptedPrintUpload(null, 'scan.JPG')).toBe(true);
    expect(isAcceptedPrintUpload(null, 'x.docx')).toBe(true);
    expect(
      isAcceptedPrintUpload(
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'letter.bin',
      ),
    ).toBe(true);
    expect(isAcceptedPrintUpload(null, 'notes.txt')).toBe(false);
  });
});

describe('normalizeToPdf', () => {
  it('passes through a valid PDF', async () => {
    const doc = await PDFDocument.create();
    doc.addPage();
    const original = Buffer.from(await doc.save());
    const result = await normalizeToPdf({
      bytes: original,
      mimeType: 'application/pdf',
      fileName: 'doc.pdf',
    });
    expect(result.contentType).toBe('application/pdf');
    expect(result.pageCount).toBe(1);
    expect(result.pdfBytes.subarray(0, 5).toString('ascii')).toBe('%PDF-');
  });

  it('converts JPEG to a single-page PDF', async () => {
    const result = await normalizeToPdf({
      bytes: TINY_JPEG,
      mimeType: 'image/jpeg',
      fileName: 'photo.jpg',
    });
    expect(result.pageCount).toBe(1);
    expect(result.pdfBytes.subarray(0, 5).toString('ascii')).toBe('%PDF-');
  });

  it('converts PNG to a single-page PDF', async () => {
    const result = await normalizeToPdf({
      bytes: TINY_PNG,
      fileName: 'scan.png',
    });
    expect(result.pageCount).toBe(1);
  });

  it('rejects unsupported / garbage bytes', async () => {
    try {
      await normalizeToPdf({
        bytes: Buffer.from('not-a-document'),
        fileName: 'notes.txt',
      });
      expect.fail('expected AppError');
    } catch (error) {
      expect(isAppError(error)).toBe(true);
      if (isAppError(error)) {
        expect(error.code).toBe('unsupported_format');
      }
    }
  });

  it('converts DOCX via injected LibreOffice execFile', async () => {
    const stubDoc = await PDFDocument.create();
    stubDoc.addPage();
    const stubPdf = Buffer.from(await stubDoc.save());

    const execFile: DocxExecFile = async (_bin, args) => {
      const outDir = args[args.indexOf('--outdir') + 1];
      await fs.writeFile(`${outDir}/input.pdf`, stubPdf);
      return { stdout: '', stderr: '' };
    };

    const result = await normalizeToPdf({
      bytes: FAKE_DOCX,
      fileName: 'letter.docx',
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      docx: {
        bin: 'soffice',
        timeoutMs: 5_000,
        maxConcurrent: 1,
        execFile,
      },
    });
    expect(result.pageCount).toBe(1);
    expect(result.pdfBytes.subarray(0, 5).toString('ascii')).toBe('%PDF-');
  });
});

/** Minimal ZIP (store-only) for a tiny OOXML .docx — no extra deps. */
function zipStore(entries: Array<{ name: string; data: Buffer }>): Buffer {
  const parts: Buffer[] = [];
  const central: Buffer[] = [];
  let offset = 0;
  for (const entry of entries) {
    const nameBuf = Buffer.from(entry.name, 'utf8');
    const local = Buffer.alloc(30 + nameBuf.length);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0, 6);
    local.writeUInt16LE(0, 8); // store
    local.writeUInt16LE(0, 10);
    local.writeUInt16LE(0, 12);
    local.writeUInt32LE(0, 14); // crc skipped for Writer smoke
    local.writeUInt32LE(entry.data.length, 18);
    local.writeUInt32LE(entry.data.length, 22);
    local.writeUInt16LE(nameBuf.length, 26);
    local.writeUInt16LE(0, 28);
    nameBuf.copy(local, 30);
    parts.push(local, entry.data);

    const cen = Buffer.alloc(46 + nameBuf.length);
    cen.writeUInt32LE(0x02014b50, 0);
    cen.writeUInt16LE(20, 4);
    cen.writeUInt16LE(20, 6);
    cen.writeUInt16LE(0, 8);
    cen.writeUInt16LE(0, 10);
    cen.writeUInt16LE(0, 12);
    cen.writeUInt16LE(0, 14);
    cen.writeUInt32LE(0, 16);
    cen.writeUInt32LE(entry.data.length, 20);
    cen.writeUInt32LE(entry.data.length, 24);
    cen.writeUInt16LE(nameBuf.length, 28);
    cen.writeUInt16LE(0, 30);
    cen.writeUInt16LE(0, 32);
    cen.writeUInt16LE(0, 34);
    cen.writeUInt16LE(0, 36);
    cen.writeUInt32LE(0, 38);
    cen.writeUInt32LE(offset, 42);
    nameBuf.copy(cen, 46);
    central.push(cen);
    offset += local.length + entry.data.length;
  }
  const centralDir = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(0, 4);
  end.writeUInt16LE(0, 6);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralDir.length, 12);
  end.writeUInt32LE(offset, 16);
  end.writeUInt16LE(0, 20);
  return Buffer.concat([...parts, centralDir, end]);
}

describe('normalizeToPdf live LibreOffice', () => {
  it('converts a real .docx when soffice is available', async () => {
    const { execFile } = await import('node:child_process');
    const { promisify } = await import('node:util');
    const run = promisify(execFile);
    try {
      await run('soffice', ['--version'], { timeout: 10_000 });
    } catch {
      // Not installed in CI / local — skip without failing the suite.
      return;
    }

    const docxBytes = zipStore([
      {
        name: '[Content_Types].xml',
        data: Buffer.from(
          `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>`,
        ),
      },
      {
        name: '_rels/.rels',
        data: Buffer.from(
          `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>`,
        ),
      },
      {
        name: 'word/document.xml',
        data: Buffer.from(
          `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body><w:p><w:r><w:t>SKP docx smoke</w:t></w:r></w:p></w:body>
</w:document>`,
        ),
      },
    ]);

    const result = await normalizeToPdf({
      bytes: docxBytes,
      fileName: 'smoke.docx',
      docx: {
        bin: 'soffice',
        timeoutMs: 60_000,
        maxConcurrent: 1,
      },
    });
    expect(result.pageCount).toBeGreaterThanOrEqual(1);
    expect(result.pdfBytes.subarray(0, 5).toString('ascii')).toBe('%PDF-');
  });
});
