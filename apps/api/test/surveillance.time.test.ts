import { describe, expect, it } from 'vitest';
import {
  formatRecordedOn,
  parseSegmentStart,
  recordedOnDate,
} from '../src/modules/surveillance/surveillance.time.js';

describe('surveillance.time', () => {
  it('parses HHmmss_ filename into a UTC Date', () => {
    expect(parseSegmentStart('2026-09-03', '143052_abc.mp4').toISOString()).toBe(
      '2026-09-03T14:30:52.000Z',
    );
  });

  it('rejects malformed filenames', () => {
    expect(() => parseSegmentStart('2026-09-03', 'clip.mp4')).toThrow();
  });

  it('formats recordedOn dates', () => {
    expect(formatRecordedOn(recordedOnDate('2026-09-03'))).toBe('2026-09-03');
  });
});
