import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import type { EmergencyContactBody } from './emergency_contacts.schemas.js';

function normalizeHelplinePhone(raw: string): string {
  const cleaned = raw.replace(/\s+/g, '').trim();
  if (!cleaned) {
    throw new AppError('invalid_phone', 'Enter a phone or helpline number', 400);
  }
  if (!/^[\d+\-]+$/.test(cleaned)) {
    throw new AppError(
      'invalid_phone',
      'Helpline numbers may only include digits, + and -',
      400,
    );
  }
  if (cleaned.replace(/\D/g, '').length < 2) {
    throw new AppError('invalid_phone', 'Enter a valid helpline number', 400);
  }
  return cleaned.slice(0, 32);
}

function mapRow(row: {
  id: string;
  name: string;
  phone: string;
  icon: string;
  sortOrder: number;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: row.id,
    name: row.name,
    phone: row.phone,
    icon: row.icon,
    sortOrder: row.sortOrder,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

export class EmergencyContactsService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {}

  async list() {
    const rows = await this.db.emergencyContact.findMany({
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
    return {
      items: rows.map(mapRow),
    };
  }

  async create(input: EmergencyContactBody, adminId: string, correlationId?: string) {
    const phone = normalizeHelplinePhone(input.phone);
    const sortOrder =
      input.sortOrder ??
      ((
        await this.db.emergencyContact.aggregate({ _max: { sortOrder: true } })
      )._max.sortOrder ?? 0) + 1;

    const row = await this.db.emergencyContact.create({
      data: {
        name: input.name.trim(),
        phone,
        icon: input.icon,
        sortOrder,
      },
    });

    await this.audit.record({
      action: 'emergency_contact.created',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'emergency_contact',
      resourceId: row.id,
      correlationId,
      metadata: { name: row.name, phone: row.phone },
    });

    return mapRow(row);
  }

  async update(
    id: string,
    input: EmergencyContactBody,
    adminId: string,
    correlationId?: string,
  ) {
    const existing = await this.db.emergencyContact.findUnique({ where: { id } });
    if (!existing) {
      throw new AppError('not_found', 'Emergency contact not found', 404);
    }

    const phone = normalizeHelplinePhone(input.phone);
    const row = await this.db.emergencyContact.update({
      where: { id },
      data: {
        name: input.name.trim(),
        phone,
        icon: input.icon,
        sortOrder: input.sortOrder ?? existing.sortOrder,
      },
    });

    await this.audit.record({
      action: 'emergency_contact.updated',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'emergency_contact',
      resourceId: row.id,
      correlationId,
      metadata: { name: row.name, phone: row.phone },
    });

    return mapRow(row);
  }

  async remove(id: string, adminId: string, correlationId?: string) {
    const row = await this.db.emergencyContact.findUnique({ where: { id } });
    if (!row) {
      throw new AppError('not_found', 'Emergency contact not found', 404);
    }
    await this.db.emergencyContact.delete({ where: { id } });
    await this.audit.record({
      action: 'emergency_contact.removed',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'emergency_contact',
      resourceId: id,
      correlationId,
      metadata: { name: row.name, phone: row.phone },
    });
  }
}
