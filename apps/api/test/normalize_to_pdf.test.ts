import { describe, expect, it } from 'vitest';
import { PDFDocument } from 'pdf-lib';
import { isAppError } from '../src/shared/errors.js';
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

describe('isAcceptedPrintUpload', () => {
  it('accepts pdf jpg png by mime or extension', () => {
    expect(isAcceptedPrintUpload('application/pdf', 'a.bin')).toBe(true);
    expect(isAcceptedPrintUpload('image/jpeg', null)).toBe(true);
    expect(isAcceptedPrintUpload('image/png', null)).toBe(true);
    expect(isAcceptedPrintUpload(null, 'scan.JPG')).toBe(true);
    expect(isAcceptedPrintUpload(null, 'x.docx')).toBe(false);
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
});
