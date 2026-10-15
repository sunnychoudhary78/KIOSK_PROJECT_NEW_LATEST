import { describe, expect, it } from 'vitest';
import {
  isWithinLocalTimeWindow,
  parseLocalHmm,
  periodKeyFor,
} from '../src/modules/print_quota/print_quota.time.js';

describe('parseLocalHmm', () => {
  it('parses valid times', () => {
    expect(parseLocalHmm('22:00')).toBe(22 * 60);
    expect(parseLocalHmm('00:00')).toBe(0);
    expect(parseLocalHmm('10:30')).toBe(10 * 60 + 30);
  });

  it('rejects invalid', () => {
    expect(parseLocalHmm(null)).toBeNull();
    expect(parseLocalHmm('25:00')).toBeNull();
    expect(parseLocalHmm('9:00')).toBeNull();
  });
});

describe('isWithinLocalTimeWindow', () => {
  it('handles same-day window', () => {
    // 2026-04-15 14:00 UTC = 19:30 IST
    const afternoonIst = new Date('2026-04-15T14:00:00.000Z');
    expect(isWithinLocalTimeWindow(afternoonIst, '12:00', '20:00')).toBe(true);
    expect(isWithinLocalTimeWindow(afternoonIst, '20:00', '22:00')).toBe(false);
  });

  it('handles overnight window crossing midnight', () => {
    // 2026-04-15 17:00 UTC = 22:30 IST → inside 22:00–10:00
    const late = new Date('2026-04-15T17:00:00.000Z');
    expect(isWithinLocalTimeWindow(late, '22:00', '10:00')).toBe(true);
    // 2026-04-15 06:00 UTC = 11:30 IST → outside
    const midday = new Date('2026-04-15T06:00:00.000Z');
    expect(isWithinLocalTimeWindow(midday, '22:00', '10:00')).toBe(false);
    // 2026-04-15 03:00 UTC = 08:30 IST → inside overnight
    const morning = new Date('2026-04-15T03:00:00.000Z');
    expect(isWithinLocalTimeWindow(morning, '22:00', '10:00')).toBe(true);
  });

  it('returns false when either bound missing', () => {
    const now = new Date('2026-04-15T17:00:00.000Z');
    expect(isWithinLocalTimeWindow(now, '22:00', null)).toBe(false);
    expect(isWithinLocalTimeWindow(now, null, '10:00')).toBe(false);
  });
});

describe('periodKeyFor', () => {
  it('builds daily key in Asia/Kolkata', () => {
    // 2026-04-14 20:00 UTC = 2026-04-15 01:30 IST
    const d = new Date('2026-04-14T20:00:00.000Z');
    expect(periodKeyFor(d, 'daily')).toBe('2026-04-15');
  });

  it('builds monthly key', () => {
    const d = new Date('2026-04-14T20:00:00.000Z');
    expect(periodKeyFor(d, 'monthly')).toBe('2026-04');
  });

  it('builds weekly key', () => {
    const d = new Date('2026-04-14T20:00:00.000Z'); // Wed 2026-04-15 IST
    expect(periodKeyFor(d, 'weekly')).toMatch(/^2026-W\d{2}$/);
  });
});
