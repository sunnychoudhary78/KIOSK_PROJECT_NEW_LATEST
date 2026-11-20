import type { AstrologyContactKind as PrismaKind, Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import type {
  AstrologyContactBody,
  AstrologyContactKind,
} from './astrology_contacts.schemas.js';

function mapRow(row: {
  id: string;
  kind: PrismaKind;
  name: string;
  phone: string;
  rating: Prisma.Decimal;
  sortOrder: number;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: row.id,
    kind: row.kind,
    name: row.name,
    phone: row.phone,
    rating: Number(row.rating),
    sortOrder: row.sortOrder,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

export class AstrologyContactsService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {}

  async list(kind?: AstrologyContactKind) {
    const rows = await this.db.astrologyContact.findMany({
      where: kind ? { kind } : undefined,
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
    return {
      items: rows.map(mapRow),
    };
  }

  async create(input: AstrologyContactBody, adminId: string, correlationId?: string) {
    const sortOrder =
      input.sortOrder ??
      ((
        await this.db.astrologyContact.aggregate({
          where: { kind: input.kind },
          _max: { sortOrder: true },
        })
      )._max.sortOrder ?? 0) + 1;

    const row = await this.db.astrologyContact.create({
      data: {
        kind: input.kind,
        name: input.name.trim(),
        phone: input.phone.trim(),
        rating: input.rating,
        sortOrder,
      },
    });

    await this.audit.record({
      action: 'astrology_contact.created',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'astrology_contact',
      resourceId: row.id,
      correlationId,
      metadata: { kind: row.kind, name: row.name, phone: row.phone },
    });

    return mapRow(row);
  }

  async update(
    id: string,
    input: AstrologyContactBody,
    adminId: string,
    correlationId?: string,
  ) {
    const existing = await this.db.astrologyContact.findUnique({ where: { id } });
    if (!existing) {
      throw new AppError('not_found', 'Astrology contact not found', 404);
    }

    const row = await this.db.astrologyContact.update({
      where: { id },
      data: {
        kind: input.kind,
        name: input.name.trim(),
        phone: input.phone.trim(),
        rating: input.rating,
        sortOrder: input.sortOrder ?? existing.sortOrder,
      },
    });

    await this.audit.record({
      action: 'astrology_contact.updated',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'astrology_contact',
      resourceId: row.id,
      correlationId,
      metadata: { kind: row.kind, name: row.name, phone: row.phone },
    });

    return mapRow(row);
  }

  async remove(id: string, adminId: string, correlationId?: string) {
    const row = await this.db.astrologyContact.findUnique({ where: { id } });
    if (!row) {
      throw new AppError('not_found', 'Astrology contact not found', 404);
    }
    await this.db.astrologyContact.delete({ where: { id } });
    await this.audit.record({
      action: 'astrology_contact.removed',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'astrology_contact',
      resourceId: id,
      correlationId,
      metadata: { kind: row.kind, name: row.name, phone: row.phone },
    });
  }
}
