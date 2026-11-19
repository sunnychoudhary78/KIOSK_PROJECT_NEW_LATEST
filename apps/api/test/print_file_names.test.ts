import { describe, expect, it } from 'vitest';
import {
  sanitizeDisplayName,
  storagePdfName,
} from '../src/modules/printing/print_file_names.js';

describe('sanitizeDisplayName', () => {
  it('keeps pdf jpg and png extensions', () => {
    expect(sanitizeDisplayName('report.pdf')).toBe('report.pdf');
    expect(sanitizeDisplayName('photo.jpg')).toBe('photo.jpg');
    expect(sanitizeDisplayName('scan.PNG')).toBe('scan.PNG');
  });

  it('sanitizes unsafe characters without changing extension', () => {
    expect(sanitizeDisplayName('my photo!.jpg')).toBe('my photo_.jpg');
    expect(sanitizeDisplayName('a/b\\c.pdf')).toBe('a_b_c.pdf');
  });
});

describe('storagePdfName', () => {
  it('forces .pdf for image display names', () => {
    expect(storagePdfName('photo.jpg')).toBe('photo.pdf');
    expect(storagePdfName('scan.png')).toBe('scan.pdf');
    expect(storagePdfName('already.pdf')).toBe('already.pdf');
  });

  it('sanitizes then appends .pdf', () => {
    expect(storagePdfName('vacation photo!.jpeg')).toBe('vacation photo_.pdf');
  });
});
