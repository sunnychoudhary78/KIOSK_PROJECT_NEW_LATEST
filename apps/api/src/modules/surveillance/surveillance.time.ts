import { AppError } from '../../shared/errors.js';

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const FILENAME_START_RE = /^(\d{2})(\d{2})(\d{2})_/;

/** Parse UTC calendar day + HHmmss_… filename into a Date (UTC). */
export function parseSegmentStart(recordedOn: string, filename: string): Date {
  if (!DATE_RE.test(recordedOn)) {
    throw new AppError('validation_error', 'recordedOn must be YYYY-MM-DD', 400);
  }
  const match = FILENAME_START_RE.exec(filename);
  if (!match) {
    throw new AppError(
      'validation_error',
      'filename must start with HHmmss_ (UTC segment start)',
      400,
    );
  }
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  const second = Number(match[3]);
  if (hour > 23 || minute > 59 || second > 59) {
    throw new AppError('validation_error', 'filename HHmmss is out of range', 400);
  }
  const iso = `${recordedOn}T${match[1]}:${match[2]}:${match[3]}.000Z`;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) {
    throw new AppError('validation_error', 'invalid segment start time', 400);
  }
  return date;
}

/** UTC calendar day as a Date at midnight (for Prisma @db.Date). */
export function recordedOnDate(recordedOn: string): Date {
  if (!DATE_RE.test(recordedOn)) {
    throw new AppError('validation_error', 'recordedOn must be YYYY-MM-DD', 400);
  }
  return new Date(`${recordedOn}T00:00:00.000Z`);
}

export function formatRecordedOn(value: Date): string {
  return value.toISOString().slice(0, 10);
}
