import { describe, expect, it } from 'vitest';
import {
  asciiFilename,
  contentDispositionInline,
} from '../src/shared/content_disposition.js';

describe('contentDispositionInline', () => {
  it('sanitizes em dash kundali titles to ASCII filename', () => {
    const header = contentDispositionInline('Kundali — Asha', true);
    expect(header).toContain('filename="Kundali - Asha.pdf"');
    expect(header.startsWith('inline;')).toBe(true);
    // Node rejects non-ASCII in header values; ASCII filename= must be clean.
    expect(/^[\x20-\x7E]*$/.test(header.split('filename*=')[0]!)).toBe(true);
  });

  it('strips quotes and control characters', () => {
    expect(asciiFilename('Report "Q1"\r\n')).toBe('Report Q1');
  });

  it('falls back when name is empty or only non-ascii', () => {
    expect(asciiFilename('')).toBe('document.pdf');
    expect(asciiFilename('कुंडली')).toBe('document.pdf');
  });

  it('adds UTF-8 filename* when original has non-ascii', () => {
    const header = contentDispositionInline('Kundali — आशा', true);
    expect(header).toMatch(/filename="Kundali -\.pdf"/);
    expect(header).toContain("filename*=UTF-8''");
    expect(header).toContain(encodeURIComponent('Kundali — आशा'));
  });

  it('leaves simple ascii names alone', () => {
    expect(contentDispositionInline('health-report.pdf')).toBe(
      'inline; filename="health-report.pdf"',
    );
  });
});
