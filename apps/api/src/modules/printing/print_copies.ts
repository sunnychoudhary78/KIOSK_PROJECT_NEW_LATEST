import { AppError } from '../../shared/errors.js';

export const MIN_PRINT_COPIES = 1;
export const MAX_PRINT_COPIES = 10;

/** Validate/clamp a copies value to 1–10. Rejects non-integers outside range. */
export function parseCopies(raw: unknown, fallback = MIN_PRINT_COPIES): number {
  if (raw === undefined || raw === null || raw === '') {
    return fallback;
  }
  const n = typeof raw === 'number' ? raw : Number.parseInt(String(raw).trim(), 10);
  if (!Number.isInteger(n) || n < MIN_PRINT_COPIES || n > MAX_PRINT_COPIES) {
    throw new AppError(
      'validation_error',
      `Copies must be an integer between ${MIN_PRINT_COPIES} and ${MAX_PRINT_COPIES}`,
      400,
    );
  }
  return n;
}

/** Parse a multer/body `copies` field (string | string[] | JSON array) into one value per file. */
export function parseCopiesList(raw: unknown, fileCount: number): number[] {
  if (fileCount <= 0) {
    return [];
  }
  if (raw === undefined || raw === null || raw === '') {
    return Array.from({ length: fileCount }, () => MIN_PRINT_COPIES);
  }

  let normalized: unknown = raw;
  if (typeof raw === 'string') {
    const trimmed = raw.trim();
    if (trimmed.startsWith('[')) {
      try {
        normalized = JSON.parse(trimmed) as unknown;
      } catch {
        normalized = trimmed.split(',');
      }
    } else if (trimmed.includes(',')) {
      normalized = trimmed.split(',');
    }
  }

  const list = Array.isArray(normalized) ? normalized : [normalized];
  if (list.length !== 1 && list.length !== fileCount) {
    throw new AppError(
      'validation_error',
      `Expected ${fileCount} copies values (one per file), got ${list.length}`,
      400,
    );
  }
  if (list.length === 1 && fileCount > 1) {
    const value = parseCopies(list[0]);
    return Array.from({ length: fileCount }, () => value);
  }
  return list.map((item) => parseCopies(item));
}

export function billablePages(pageCount: number, copies: number): number {
  const pages = Math.max(0, Math.floor(pageCount));
  const n = Math.max(MIN_PRINT_COPIES, Math.floor(copies));
  return pages * n;
}
