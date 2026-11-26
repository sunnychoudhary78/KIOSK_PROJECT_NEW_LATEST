import { mkdir, readFile, unlink, writeFile } from 'node:fs/promises';
import { extname, join } from 'node:path';
import { Prisma, type AstrologyContactKind as PrismaKind } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import type {
  AstrologyContactBody,
  AstrologyContactKind,
} from './astrology_contacts.schemas.js';

const PHOTO_UPLOAD_DIR = join(process.cwd(), 'uploads', 'astrology-contacts');

function extensionFor(mimetype?: string, originalname?: string) {
  if (mimetype === 'image/png') return '.png';
  if (mimetype === 'image/webp') return '.webp';
  if (mimetype === 'image/gif') return '.gif';
  if (mimetype === 'image/jpeg' || mimetype === 'image/jpg') return '.jpg';
  const fromName = originalname ? extname(originalname).toLowerCase() : '';
  if (['.png', '.jpg', '.jpeg', '.webp', '.gif'].includes(fromName)) {
    return fromName === '.jpeg' ? '.jpg' : fromName;
  }
  return '.jpg';
}

function mapRow(row: {
  id: string;
  kind: PrismaKind;
  name: string;
  phone: string;
  rating: Prisma.Decimal;
  sortOrder: number;
  showNumberClicks: number;
  photoStoragePath: string | null;
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
    showNumberClicks: row.showNumberClicks,
    photoUrl: row.photoStoragePath
      ? `/astrology-contacts/${row.id}/photo`
      : null,
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
    if (row.photoStoragePath) {
      await unlink(row.photoStoragePath).catch(() => undefined);
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

  async setPhoto(
    contactId: string,
    file: { buffer: Buffer; mimetype?: string; originalname: string },
    adminId: string,
    correlationId?: string,
  ) {
    const existing = await this.db.astrologyContact.findUnique({
      where: { id: contactId },
      select: { id: true, photoStoragePath: true, name: true },
    });
    if (!existing) {
      throw new AppError('not_found', 'Astrology contact not found', 404);
    }

    const mime = file.mimetype ?? '';
    if (!mime.startsWith('image/')) {
      throw new AppError('invalid_file', 'Photo must be an image', 400);
    }

    await mkdir(PHOTO_UPLOAD_DIR, { recursive: true });
    const ext = extensionFor(file.mimetype, file.originalname);
    const storagePath = join(PHOTO_UPLOAD_DIR, `${contactId}${ext}`);
    await writeFile(storagePath, file.buffer);

    if (existing.photoStoragePath && existing.photoStoragePath !== storagePath) {
      await unlink(existing.photoStoragePath).catch(() => undefined);
    }

    const row = await this.db.astrologyContact.update({
      where: { id: contactId },
      data: { photoStoragePath: storagePath },
    });

    await this.audit.record({
      action: 'astrology_contact.photo_set',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'astrology_contact',
      resourceId: contactId,
      correlationId,
      metadata: { name: existing.name },
    });

    return mapRow(row);
  }

  async readPhoto(contactId: string): Promise<{ bytes: Buffer; contentType: string }> {
    const row = await this.db.astrologyContact.findUnique({
      where: { id: contactId },
      select: { photoStoragePath: true },
    });
    if (!row?.photoStoragePath) {
      throw new AppError('not_found', 'Photo not found', 404);
    }
    const bytes = await readFile(row.photoStoragePath);
    const ext = extname(row.photoStoragePath).toLowerCase();
    const contentType =
      ext === '.png'
        ? 'image/png'
        : ext === '.webp'
          ? 'image/webp'
          : ext === '.gif'
            ? 'image/gif'
            : 'image/jpeg';
    return { bytes, contentType };
  }

  async reveal(id: string) {
    try {
      const row = await this.db.astrologyContact.update({
        where: { id },
        data: { showNumberClicks: { increment: 1 } },
        select: { id: true, showNumberClicks: true },
      });
      return {
        id: row.id,
        showNumberClicks: row.showNumberClicks,
      };
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2025'
      ) {
        throw new AppError('not_found', 'Astrology contact not found', 404);
      }
      throw error;
    }
  }
}
