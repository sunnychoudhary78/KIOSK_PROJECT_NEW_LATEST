import { Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import { normalizePhone } from '../../shared/otp.js';
import type { AuditService } from '../audit/audit.service.js';
import {
  SOCIETY_IMPORT_MAX_INVALID,
  parseCsvSocietyRows,
  parseXlsxSocietyRows,
  type ParsedSocietyRow,
} from './society_phones.parse.js';
import {
  normalizeSocietyColor,
  type SocietyPhoneColor,
} from './society_phones.schemas.js';

export type SocietyImportResult = {
  added: number;
  duplicate: number;
  invalid: Array<{ row: number; value: string; reason: string }>;
  invalidCount: number;
};

export type SocietyPhoneInput = {
  phone: string;
  name: string;
  societyName: string;
  color?: SocietyPhoneColor;
};

function invalidPhone(): AppError {
  return new AppError('invalid_phone', 'Enter a valid 10-digit Indian mobile number', 400);
}

function normalizeName(raw: string, max = 120): string {
  return raw.trim().replace(/\s+/g, ' ').slice(0, max);
}

function toItem(row: {
  id: string;
  phone: string;
  name: string;
  societyName: string;
  color: string;
  createdAt: Date;
}) {
  return {
    id: row.id,
    phone: row.phone,
    name: row.name,
    societyName: row.societyName,
    color: normalizeSocietyColor(row.color),
    createdAt: row.createdAt.toISOString(),
  };
}

export class SocietyPhonesService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {}

  async list(input: { q?: string; limit?: number } = {}) {
    const limit = Math.min(200, Math.max(1, Math.floor(input.limit ?? 50)));
    const q = (input.q ?? '').trim();
    const digits = q.replace(/\D/g, '');
    const where =
      q.length === 0
        ? undefined
        : {
            OR: [
              ...(digits ? [{ phone: { contains: digits } }] : []),
              { name: { contains: q, mode: 'insensitive' as const } },
              { societyName: { contains: q, mode: 'insensitive' as const } },
            ],
          };
    const rows = await this.db.societyPhone.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: {
        id: true,
        phone: true,
        name: true,
        societyName: true,
        color: true,
        createdAt: true,
      },
    });
    const total = await this.db.societyPhone.count({ where });
    return {
      total,
      items: rows.map(toItem),
    };
  }

  async add(input: SocietyPhoneInput, adminId: string, correlationId?: string) {
    const name = normalizeName(input.name);
    if (!name) {
      throw new AppError('invalid_name', 'Enter a person name for this society number', 400);
    }
    const societyName = normalizeName(input.societyName, 160);
    if (!societyName) {
      throw new AppError('invalid_society_name', 'Enter the society name', 400);
    }
    const color = normalizeSocietyColor(input.color);

    let phone: string;
    try {
      phone = normalizePhone(input.phone);
    } catch {
      throw invalidPhone();
    }

    const existing = await this.db.societyPhone.findUnique({ where: { phone } });
    if (existing) {
      throw new AppError('society_phone_exists', 'This number is already on the society list', 409);
    }

    try {
      const row = await this.db.societyPhone.create({
        data: { phone, name, societyName, color },
      });
      await this.audit.record({
        action: 'society_phone.added',
        principalType: 'admin',
        principalId: adminId,
        resourceType: 'society_phone',
        resourceId: row.id,
        correlationId,
        metadata: { phone, name, societyName, color },
      });
      return toItem(row);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new AppError('society_phone_exists', 'This number is already on the society list', 409);
      }
      throw error;
    }
  }

  async remove(id: string, adminId: string, correlationId?: string) {
    const row = await this.db.societyPhone.findUnique({ where: { id } });
    if (!row) {
      throw new AppError('not_found', 'Society phone not found', 404);
    }
    await this.db.societyPhone.delete({ where: { id } });
    await this.audit.record({
      action: 'society_phone.removed',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'society_phone',
      resourceId: id,
      correlationId,
      metadata: {
        phone: row.phone,
        name: row.name,
        societyName: row.societyName,
        color: row.color,
      },
    });
  }

  async importFile(
    file: { originalname: string; buffer: Buffer },
    adminId: string,
    correlationId?: string,
  ): Promise<SocietyImportResult> {
    const name = file.originalname.toLowerCase();
    if (name.endsWith('.xls') && !name.endsWith('.xlsx')) {
      throw new AppError(
        'invalid_file',
        'Old .xls files are not supported. Save the sheet as .xlsx or .csv.',
        400,
      );
    }
    let cells: ParsedSocietyRow[];
    if (name.endsWith('.csv') || name.endsWith('.txt')) {
      cells = parseCsvSocietyRows(file.buffer.toString('utf8'));
    } else if (name.endsWith('.xlsx')) {
      cells = await parseXlsxSocietyRows(file.buffer);
    } else {
      throw new AppError('invalid_file', 'Upload a .csv or .xlsx file', 400);
    }

    const invalid: SocietyImportResult['invalid'] = [];
    let invalidCount = 0;
    let inFileDuplicates = 0;
    const unique: Array<{
      phone: string;
      name: string;
      societyName: string;
      color: SocietyPhoneColor;
    }> = [];
    const seen = new Set<string>();

    for (const cell of cells) {
      let phone: string;
      try {
        phone = normalizePhone(cell.phoneRaw);
      } catch {
        invalidCount += 1;
        if (invalid.length < SOCIETY_IMPORT_MAX_INVALID) {
          invalid.push({ row: cell.row, value: cell.phoneRaw, reason: 'invalid_phone' });
        }
        continue;
      }
      if (seen.has(phone)) {
        inFileDuplicates += 1;
        continue;
      }
      seen.add(phone);
      unique.push({
        phone,
        name: normalizeName(cell.name) || phone,
        societyName: normalizeName(cell.societyName, 160),
        color: cell.color,
      });
    }

    const existing =
      unique.length === 0
        ? []
        : await this.db.societyPhone.findMany({
            where: { phone: { in: unique.map((row) => row.phone) } },
            select: { phone: true },
          });
    const existingSet = new Set(existing.map((row) => row.phone));
    const toInsert = unique.filter((row) => !existingSet.has(row.phone));
    let added = 0;
    if (toInsert.length > 0) {
      const result = await this.db.societyPhone.createMany({
        data: toInsert.map((row) => ({
          phone: row.phone,
          name: row.name,
          societyName: row.societyName,
          color: row.color,
        })),
        skipDuplicates: true,
      });
      added = result.count;
    }
    const duplicate = inFileDuplicates + (unique.length - toInsert.length) + (toInsert.length - added);

    await this.audit.record({
      action: 'society_phone.imported',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'society_phone',
      correlationId,
      metadata: { added, duplicate, invalidCount },
    });

    return { added, duplicate, invalid, invalidCount };
  }
}
