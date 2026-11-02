import { Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import { normalizePhone } from '../../shared/otp.js';
import type { AuditService } from '../audit/audit.service.js';
import {
  SOCIETY_IMPORT_MAX_INVALID,
  parseCsvPhones,
  parseXlsxPhones,
  type ParsedPhoneCell,
} from './society_phones.parse.js';

export type SocietyImportResult = {
  added: number;
  duplicate: number;
  invalid: Array<{ row: number; value: string; reason: string }>;
  invalidCount: number;
};

function invalidPhone(): AppError {
  return new AppError('invalid_phone', 'Enter a valid 10-digit Indian mobile number', 400);
}

export class SocietyPhonesService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {}

  async list(input: { q?: string; limit?: number } = {}) {
    const limit = Math.min(200, Math.max(1, Math.floor(input.limit ?? 50)));
    const digits = (input.q ?? '').replace(/\D/g, '');
    const rows = await this.db.societyPhone.findMany({
      where: digits ? { phone: { contains: digits } } : undefined,
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { id: true, phone: true, createdAt: true },
    });
    const total = await this.db.societyPhone.count({
      where: digits ? { phone: { contains: digits } } : undefined,
    });
    return {
      total,
      items: rows.map((row) => ({
        id: row.id,
        phone: row.phone,
        createdAt: row.createdAt.toISOString(),
      })),
    };
  }

  async add(phoneRaw: string, adminId: string, correlationId?: string) {
    let phone: string;
    try {
      phone = normalizePhone(phoneRaw);
    } catch {
      throw invalidPhone();
    }

    const existing = await this.db.societyPhone.findUnique({ where: { phone } });
    if (existing) {
      throw new AppError('society_phone_exists', 'This number is already on the society list', 409);
    }

    try {
      const row = await this.db.societyPhone.create({ data: { phone } });
      await this.audit.record({
        action: 'society_phone.added',
        principalType: 'admin',
        principalId: adminId,
        resourceType: 'society_phone',
        resourceId: row.id,
        correlationId,
        metadata: { phone },
      });
      return { id: row.id, phone: row.phone, createdAt: row.createdAt.toISOString() };
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
      metadata: { phone: row.phone },
    });
  }

  async importFile(
    file: { originalname: string; buffer: Buffer },
    adminId: string,
    correlationId?: string,
  ): Promise<SocietyImportResult> {
    const name = file.originalname.toLowerCase();
    if (name.endsWith('.xls') && !name.endsWith('.xlsx')) {
      throw new AppError('invalid_file', 'Old .xls files are not supported. Save the sheet as .xlsx or .csv.', 400);
    }
    let cells: ParsedPhoneCell[];
    if (name.endsWith('.csv') || name.endsWith('.txt')) {
      cells = parseCsvPhones(file.buffer.toString('utf8'));
    } else if (name.endsWith('.xlsx')) {
      cells = await parseXlsxPhones(file.buffer);
    } else {
      throw new AppError('invalid_file', 'Upload a .csv or .xlsx file', 400);
    }

    const invalid: SocietyImportResult['invalid'] = [];
    let invalidCount = 0;
    let inFileDuplicates = 0;
    const unique: string[] = [];
    const seen = new Set<string>();

    for (const cell of cells) {
      let phone: string;
      try {
        phone = normalizePhone(cell.raw);
      } catch {
        invalidCount += 1;
        if (invalid.length < SOCIETY_IMPORT_MAX_INVALID) {
          invalid.push({ row: cell.row, value: cell.raw, reason: 'invalid_phone' });
        }
        continue;
      }
      if (seen.has(phone)) {
        inFileDuplicates += 1;
        continue;
      }
      seen.add(phone);
      unique.push(phone);
    }

    const existing =
      unique.length === 0
        ? []
        : await this.db.societyPhone.findMany({
            where: { phone: { in: unique } },
            select: { phone: true },
          });
    const existingSet = new Set(existing.map((row) => row.phone));
    const toInsert = unique.filter((phone) => !existingSet.has(phone));
    let added = 0;
    if (toInsert.length > 0) {
      const result = await this.db.societyPhone.createMany({
        data: toInsert.map((phone) => ({ phone })),
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
