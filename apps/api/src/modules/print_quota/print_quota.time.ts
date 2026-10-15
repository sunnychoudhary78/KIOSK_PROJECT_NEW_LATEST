import type { PrintFreeQuotaPeriod } from '../platform_settings/platform_settings.defaults.js';

export const PRINT_QUOTA_TIMEZONE = 'Asia/Kolkata';

/** Minutes since local midnight in Asia/Kolkata for `date`. */
export function kolkataMinutesSinceMidnight(date: Date): number {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: PRINT_QUOTA_TIMEZONE,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(date);
  const hour = Number(parts.find((p) => p.type === 'hour')?.value ?? '0');
  const minute = Number(parts.find((p) => p.type === 'minute')?.value ?? '0');
  // Intl may emit "24" for midnight in some engines; normalize.
  const normalizedHour = hour === 24 ? 0 : hour;
  return normalizedHour * 60 + minute;
}

/** Parse HH:mm to minutes since midnight; returns null if invalid. */
export function parseLocalHmm(value: string | null | undefined): number | null {
  if (!value) return null;
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(value.trim());
  if (!match) return null;
  return Number(match[1]) * 60 + Number(match[2]);
}

/**
 * True when local Asia/Kolkata time is inside [from, to).
 * If from > to, the window wraps past midnight.
 */
export function isWithinLocalTimeWindow(
  now: Date,
  fromHmm: string | null | undefined,
  toHmm: string | null | undefined,
): boolean {
  const from = parseLocalHmm(fromHmm);
  const to = parseLocalHmm(toHmm);
  if (from === null || to === null) return false;
  if (from === to) return true; // full-day disable
  const minutes = kolkataMinutesSinceMidnight(now);
  if (from < to) {
    return minutes >= from && minutes < to;
  }
  return minutes >= from || minutes < to;
}

function kolkataYmd(date: Date): { year: number; month: number; day: number } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: PRINT_QUOTA_TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const year = Number(parts.find((p) => p.type === 'year')?.value);
  const month = Number(parts.find((p) => p.type === 'month')?.value);
  const day = Number(parts.find((p) => p.type === 'day')?.value);
  return { year, month, day };
}

/** ISO week number (1–53) for a UTC calendar date constructed from Y-M-D. */
function isoWeekKey(year: number, month: number, day: number): string {
  // Use UTC noon to avoid DST edge issues when deriving week.
  const utc = new Date(Date.UTC(year, month - 1, day, 12, 0, 0));
  const dayNum = utc.getUTCDay() || 7;
  utc.setUTCDate(utc.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(utc.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((utc.getTime() - yearStart.getTime()) / 86_400_000 + 1) / 7);
  const isoYear = utc.getUTCFullYear();
  return `${isoYear}-W${String(week).padStart(2, '0')}`;
}

export function periodKeyFor(date: Date, period: PrintFreeQuotaPeriod): string {
  const { year, month, day } = kolkataYmd(date);
  if (period === 'daily') {
    return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  }
  if (period === 'monthly') {
    return `${year}-${String(month).padStart(2, '0')}`;
  }
  return isoWeekKey(year, month, day);
}
