import ExcelJS from 'exceljs';
import { AppError } from '../../shared/errors.js';

export const SOCIETY_IMPORT_MAX_ROWS = 5_000;
export const SOCIETY_IMPORT_MAX_INVALID = 50;

const HEADER_NAMES = new Set(['phone', 'mobile', 'number', 'phonenumber', 'mobilenumber']);

export type ParsedPhoneCell = {
  row: number;
  raw: string;
};

function headerIndex(cells: string[]): number {
  return cells.findIndex((cell) => HEADER_NAMES.has(cell.trim().toLowerCase().replace(/[\s_-]+/g, '')));
}

function rowsToCells(rows: string[][]): ParsedPhoneCell[] {
  if (rows.length === 0) return [];
  const first = rows[0] ?? [];
  const header = headerIndex(first);
  const column = header >= 0 ? header : 0;
  const start = header >= 0 ? 1 : 0;
  const values: ParsedPhoneCell[] = [];
  for (let index = start; index < rows.length; index += 1) {
    const raw = (rows[index]?.[column] ?? '').trim();
    if (!raw) continue;
    values.push({ row: index + 1, raw });
  }
  if (values.length > SOCIETY_IMPORT_MAX_ROWS) {
    throw new AppError(
      'too_many_rows',
      `Upload has more than ${SOCIETY_IMPORT_MAX_ROWS} phone numbers`,
      400,
    );
  }
  return values;
}

function splitCsvLine(line: string): string[] {
  const cells: string[] = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (inQuotes) {
      if (ch === '"') {
        if (line[i + 1] === '"') {
          current += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        current += ch ?? '';
      }
    } else if (ch === '"') {
      inQuotes = true;
    } else if (ch === ',') {
      cells.push(current);
      current = '';
    } else {
      current += ch ?? '';
    }
  }
  cells.push(current);
  return cells;
}

export function parseCsvPhones(text: string): ParsedPhoneCell[] {
  const cleaned = text.replace(/^\uFEFF/, '');
  const lines = cleaned.split(/\r?\n/);
  return rowsToCells(lines.map((line) => splitCsvLine(line).map((cell) => cell.trim())));
}

function cellToString(value: unknown): string {
  if (value == null) return '';
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Number.isInteger(value) ? String(Math.trunc(value)) : String(value);
  }
  if (typeof value === 'string') return value.trim();
  if (typeof value === 'boolean') return '';
  if (value instanceof Date) return '';
  if (typeof value === 'object') {
    const record = value as Record<string, unknown>;
    if (typeof record.text === 'string') return record.text.trim();
    if (Array.isArray(record.richText)) {
      return record.richText
        .map((part) => {
          if (part && typeof part === 'object' && 'text' in part) {
            return String((part as { text: unknown }).text);
          }
          return '';
        })
        .join('')
        .trim();
    }
    if ('result' in record) return cellToString(record.result);
  }
  return '';
}

export async function parseXlsxPhones(buffer: Buffer): Promise<ParsedPhoneCell[]> {
  const workbook = new ExcelJS.Workbook();
  try {
    await workbook.xlsx.load(buffer as unknown as Parameters<typeof workbook.xlsx.load>[0]);
  } catch {
    throw new AppError('invalid_file', 'Could not read that Excel file. Save it as .xlsx or .csv.', 400);
  }
  const sheet = workbook.worksheets[0];
  if (!sheet) return [];
  const rows: Array<{ rowNumber: number; cells: string[] }> = [];
  sheet.eachRow({ includeEmpty: false }, (row) => {
    const values = row.values;
    const cells: string[] = [];
    if (Array.isArray(values)) {
      for (let index = 1; index < values.length; index += 1) {
        cells.push(cellToString(values[index]));
      }
    }
    if (cells.some((cell) => cell.trim().length > 0)) {
      rows.push({ rowNumber: row.number, cells });
    }
  });
  if (rows.length === 0) return [];
  const header = headerIndex(rows[0]?.cells ?? []);
  const column = header >= 0 ? header : 0;
  const start = header >= 0 ? 1 : 0;
  const values: ParsedPhoneCell[] = [];
  for (let index = start; index < rows.length; index += 1) {
    const sheetRow = rows[index];
    if (!sheetRow) continue;
    const raw = (sheetRow.cells[column] ?? '').trim();
    if (!raw) continue;
    values.push({ row: sheetRow.rowNumber, raw });
  }
  if (values.length > SOCIETY_IMPORT_MAX_ROWS) {
    throw new AppError(
      'too_many_rows',
      `Upload has more than ${SOCIETY_IMPORT_MAX_ROWS} phone numbers`,
      400,
    );
  }
  return values;
}
