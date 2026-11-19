import { describe, expect, it } from 'vitest';
import {
  billablePages,
  parseCopies,
  parseCopiesList,
} from '../src/modules/printing/print_copies.js';

describe('parseCopies', () => {
  it('defaults missing values to 1', () => {
    expect(parseCopies(undefined)).toBe(1);
    expect(parseCopies(null)).toBe(1);
    expect(parseCopies('')).toBe(1);
  });

  it('accepts integers 1–10', () => {
    expect(parseCopies(1)).toBe(1);
    expect(parseCopies('3')).toBe(3);
    expect(parseCopies(10)).toBe(10);
  });

  it('rejects 0 and 11', () => {
    expect(() => parseCopies(0)).toThrow(/Copies must be an integer/);
    expect(() => parseCopies(11)).toThrow(/Copies must be an integer/);
  });
});

describe('parseCopiesList', () => {
  it('defaults to one copy per file when omitted', () => {
    expect(parseCopiesList(undefined, 3)).toEqual([1, 1, 1]);
  });

  it('parses parallel FormData string[] values one-per-file', () => {
    expect(parseCopiesList(['2', '1', '4'], 3)).toEqual([2, 1, 4]);
  });

  it('parses JSON array field used by mobile', () => {
    expect(parseCopiesList('[3,1,2]', 3)).toEqual([3, 1, 2]);
  });

  it('broadcasts a single value across files', () => {
    expect(parseCopiesList('2', 3)).toEqual([2, 2, 2]);
  });

  it('rejects mismatched list length', () => {
    expect(() => parseCopiesList(['1', '2'], 3)).toThrow(/Expected 3 copies values/);
  });
});

describe('billablePages', () => {
  it('multiplies unique pages by copies', () => {
    expect(billablePages(1, 3)).toBe(3);
    expect(billablePages(4, 2)).toBe(8);
  });
});
