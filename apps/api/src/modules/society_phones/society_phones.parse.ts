import ExcelJS from 'exceljs';
import { AppError } from '../../shared/errors.js';
import { normalizeSocietyColor, type SocietyPhoneColor } from './society_phones.schemas.js';

export const SOCIETY_IMPORT_MAX_ROWS = 5_000;
export const SOCIETY_IMPORT_MAX_INVALID = 50;

const PHONE_HEADERS = new Set(['phone', 'mobile', 'number', 'phonenumber', 'mobilenumber']);
const NAME_HEADERS = new Set(['name', 'fullname', 'resident', 'residentname', 'member', 'membername']);
const SOCIETY_NAME_HEADERS = new Set([
  'society',
  'societyname',
  'building',
  'buildingname',
  'complex',
  'complexname',
  'apartment',
  'apartmentname',
]);
const COLOR_HEADERS = new Set(['color', 'colour', 'tag', 'tagcolor']);

export type ParsedSocietyRow = {
  row: number;
  phoneRaw: string;
  name: string;
  societyName: string;
  color: SocietyPhoneColor;
};

export type ParsedPhoneCell = {
  row: number;
  raw: string;
};

function normalizeHeader(cell: string): string {
  return cell.trim().toLowerCase().replace(/[\s_-]+/g, '');
}

function findHeader(cells: string[], names: Set<string>): number {
  return cells.findIndex((cell) => names.has(normalizeHeader(cell)));
}

function mapRowsToSociety(
  rows: Array<{ rowNumber: number; cells: string[] }>,
): ParsedSocietyRow[] {
  if (rows.length === 0) return [];
  const first = rows[0]?.cells ?? [];
  const phoneHeader = findHeader(first, PHONE_HEADERS);
  const nameHeader = findHeader(first, NAME_HEADERS);
  const societyNameHeader = findHeader(first, SOCIETY_NAME_HEADERS);
  const colorHeader = findHeader(first, COLOR_HEADERS);
  const hasHeader =
    phoneHeader >= 0 || nameHeader >= 0 || societyNameHeader >= 0 || colorHeader >= 0;
  const phoneColumn = phoneHeader >= 0 ? phoneHeader : 0;
  const start = hasHeader ? 1 : 0;
  const values: ParsedSocietyRow[] = [];
  for (let index = start; index < rows.length; index += 1) {
    const sheetRow = rows[index];
    if (!sheetRow) continue;
    const phoneRaw = (sheetRow.cells[phoneColumn] ?? '').trim();
    if (!phoneRaw) continue;
    const name = nameHeader >= 0 ? (sheetRow.cells[nameHeader] ?? '').trim() : '';
    const societyName =
      societyNameHeader >= 0 ? (sheetRow.cells[societyNameHeader] ?? '').trim() : '';
    const color =
      colorHeader >= 0 ? normalizeSocietyColor(sheetRow.cells[colorHeader]) : 'blue';
    values.push({ row: sheetRow.rowNumber, phoneRaw, name, societyName, color });
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

export function parseCsvSocietyRows(text: string): ParsedSocietyRow[] {
  const cleaned = text.replace(/^\uFEFF/, '');
  const lines = cleaned.split(/\r?\n/);
  const rows = lines.map((line, index) => ({
    rowNumber: index + 1,
    cells: splitCsvLine(line).map((cell) => cell.trim()),
  }));
  return mapRowsToSociety(rows);
}

export function parseCsvPhones(text: string): ParsedPhoneCell[] {
  return parseCsvSocietyRows(text).map((row) => ({ row: row.row, raw: row.phoneRaw }));
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

export async function parseXlsxSocietyRows(buffer: Buffer): Promise<ParsedSocietyRow[]> {
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
  return mapRowsToSociety(rows);
}

export async function parseXlsxPhones(buffer: Buffer): Promise<ParsedPhoneCell[]> {
  const rows = await parseXlsxSocietyRows(buffer);
  return rows.map((row) => ({ row: row.row, raw: row.phoneRaw }));
}
