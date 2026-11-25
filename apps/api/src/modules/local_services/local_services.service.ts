import { extname, join } from 'node:path';
import { mkdir, readFile, unlink, writeFile } from 'node:fs/promises';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import type { ServicesCatalogService } from '../services/services.service.js';
import type {
  CreateLocalServiceCategoryBody,
  CreateLocalServiceContactBody,
  UpdateLocalServiceContactBody,
} from './local_services.schemas.js';

const PHOTO_UPLOAD_DIR = join(process.cwd(), 'uploads', 'local-services');

const CONTACT_SELECT = {
  id: true,
  name: true,
  phone: true,
  sortOrder: true,
  rating: true,
  pinned: true,
  address: true,
  photoStoragePath: true,
} as const;

function slugify(name: string): string {
  const base = name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
  return base || 'service';
}

function mapContact(row: {
  id: string;
  name: string;
  phone: string;
  sortOrder: number;
  rating: number;
  pinned: boolean;
  address: string | null;
  photoStoragePath: string | null;
}) {
  return {
    id: row.id,
    name: row.name,
    phone: row.phone,
    sortOrder: row.sortOrder,
    rating: row.rating,
    pinned: row.pinned,
    address: row.address,
    photoUrl: row.photoStoragePath ? `/local-services/contacts/${row.id}/photo` : null,
  };
}

function extensionFor(mimeType: string | undefined, originalName: string): string {
  const fromName = extname(originalName).toLowerCase();
  if (fromName && fromName.length <= 8) return fromName;
  switch (mimeType) {
    case 'image/png':
      return '.png';
    case 'image/webp':
      return '.webp';
    case 'image/gif':
      return '.gif';
    default:
      return '.jpg';
  }
}

export class LocalServicesService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
    private readonly services?: ServicesCatalogService,
  ) {}

  async list(deviceId?: string) {
    if (deviceId && this.services) {
      await this.services.assertEnabled(deviceId, 'local_services');
    }
    const categories = await this.db.localServiceCategory.findMany({
      where: deviceId ? { isActive: true } : undefined,
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      select: {
        id: true,
        slug: true,
        name: true,
        sortOrder: true,
        isActive: true,
        contacts: {
          orderBy: [
            { pinned: 'desc' },
            { rating: 'desc' },
            { sortOrder: 'asc' },
            { name: 'asc' },
          ],
          select: CONTACT_SELECT,
        },
      },
    });
    return {
      categories: categories.map((category) => ({
        id: category.id,
        slug: category.slug,
        name: category.name,
        sortOrder: category.sortOrder,
        isActive: category.isActive,
        contacts: category.contacts.map(mapContact),
      })),
    };
  }

  async createCategory(
    input: CreateLocalServiceCategoryBody,
    adminId: string,
    correlationId?: string,
  ) {
    const name = input.name.trim();
    const slug = await this.uniqueSlug(name);
    const sortOrder =
      input.sortOrder ??
      ((
        await this.db.localServiceCategory.aggregate({ _max: { sortOrder: true } })
      )._max.sortOrder ?? 0) + 1;

    const row = await this.db.localServiceCategory.create({
      data: { name, slug, sortOrder, isActive: true },
      select: { id: true, slug: true, name: true, sortOrder: true, isActive: true },
    });

    await this.audit.record({
      action: 'local_service.category_created',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'local_service_category',
      resourceId: row.id,
      correlationId,
      metadata: { name: row.name, slug: row.slug },
    });

    return row;
  }

  async setCategoryStatus(
    id: string,
    isActive: boolean,
    adminId: string,
    correlationId?: string,
  ) {
    const existing = await this.db.localServiceCategory.findUnique({
      where: { id },
      select: { id: true, name: true, slug: true, isActive: true },
    });
    if (!existing) {
      throw new AppError('not_found', 'Service not found', 404);
    }

    const row = await this.db.localServiceCategory.update({
      where: { id },
      data: { isActive },
      select: { id: true, slug: true, name: true, sortOrder: true, isActive: true },
    });

    await this.audit.record({
      action: isActive ? 'local_service.category_activated' : 'local_service.category_deactivated',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'local_service_category',
      resourceId: id,
      correlationId,
      metadata: { name: existing.name, slug: existing.slug, isActive },
    });

    return row;
  }

  async removeCategory(id: string, adminId: string, correlationId?: string) {
    const existing = await this.db.localServiceCategory.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        slug: true,
        contacts: { select: { photoStoragePath: true } },
      },
    });
    if (!existing) {
      throw new AppError('not_found', 'Service not found', 404);
    }

    for (const contact of existing.contacts) {
      if (contact.photoStoragePath) {
        await unlink(contact.photoStoragePath).catch(() => undefined);
      }
    }

    await this.db.localServiceCategory.delete({ where: { id } });
    await this.audit.record({
      action: 'local_service.category_removed',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'local_service_category',
      resourceId: id,
      correlationId,
      metadata: { name: existing.name, slug: existing.slug },
    });
  }

  async createContact(
    categoryId: string,
    input: CreateLocalServiceContactBody,
    adminId: string,
    correlationId?: string,
  ) {
    const category = await this.db.localServiceCategory.findUnique({
      where: { id: categoryId },
      select: { id: true, name: true },
    });
    if (!category) {
      throw new AppError('not_found', 'Service not found', 404);
    }

    const sortOrder =
      ((
        await this.db.localServiceContact.aggregate({
          where: { categoryId },
          _max: { sortOrder: true },
        })
      )._max.sortOrder ?? 0) + 1;

    const address =
      input.address === undefined ? null : input.address?.trim() ? input.address.trim() : null;

    const row = await this.db.localServiceContact.create({
      data: {
        categoryId,
        name: input.name.trim(),
        phone: input.phone,
        sortOrder,
        rating: input.rating ?? 0,
        pinned: input.pinned ?? false,
        address,
      },
      select: CONTACT_SELECT,
    });

    await this.audit.record({
      action: 'local_service.contact_created',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'local_service_contact',
      resourceId: row.id,
      correlationId,
      metadata: {
        category: category.name,
        name: row.name,
        phone: row.phone,
        rating: row.rating,
        pinned: row.pinned,
      },
    });

    return mapContact(row);
  }

  async updateContact(
    categoryId: string,
    contactId: string,
    input: UpdateLocalServiceContactBody,
    adminId: string,
    correlationId?: string,
  ) {
    const existing = await this.db.localServiceContact.findUnique({
      where: { id: contactId },
      select: { ...CONTACT_SELECT, categoryId: true },
    });
    if (!existing || existing.categoryId !== categoryId) {
      throw new AppError('not_found', 'Contact not found', 404);
    }

    const data: {
      name?: string;
      phone?: string;
      rating?: number;
      pinned?: boolean;
      address?: string | null;
      photoStoragePath?: string | null;
    } = {};

    if (input.name !== undefined) data.name = input.name.trim();
    if (input.phone !== undefined) data.phone = input.phone;
    if (input.rating !== undefined) data.rating = input.rating;
    if (input.pinned !== undefined) data.pinned = input.pinned;
    if (input.address !== undefined) {
      data.address = input.address?.trim() ? input.address.trim() : null;
    }
    if (input.clearPhoto) {
      if (existing.photoStoragePath) {
        await unlink(existing.photoStoragePath).catch(() => undefined);
      }
      data.photoStoragePath = null;
    }

    const row = await this.db.localServiceContact.update({
      where: { id: contactId },
      data,
      select: CONTACT_SELECT,
    });

    await this.audit.record({
      action: 'local_service.contact_updated',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'local_service_contact',
      resourceId: contactId,
      correlationId,
      metadata: {
        before: {
          name: existing.name,
          phone: existing.phone,
          rating: existing.rating,
          pinned: existing.pinned,
          address: existing.address,
          hasPhoto: Boolean(existing.photoStoragePath),
        },
        after: {
          name: row.name,
          phone: row.phone,
          rating: row.rating,
          pinned: row.pinned,
          address: row.address,
          hasPhoto: Boolean(row.photoStoragePath),
        },
      },
    });

    return mapContact(row);
  }

  async setContactPhoto(
    categoryId: string,
    contactId: string,
    file: { buffer: Buffer; mimetype?: string; originalname: string },
    adminId: string,
    correlationId?: string,
  ) {
    const existing = await this.db.localServiceContact.findUnique({
      where: { id: contactId },
      select: { id: true, categoryId: true, photoStoragePath: true, name: true },
    });
    if (!existing || existing.categoryId !== categoryId) {
      throw new AppError('not_found', 'Contact not found', 404);
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

    const row = await this.db.localServiceContact.update({
      where: { id: contactId },
      data: { photoStoragePath: storagePath },
      select: CONTACT_SELECT,
    });

    await this.audit.record({
      action: 'local_service.contact_photo_set',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'local_service_contact',
      resourceId: contactId,
      correlationId,
      metadata: { name: existing.name },
    });

    return mapContact(row);
  }

  async readContactPhoto(contactId: string): Promise<{ bytes: Buffer; contentType: string }> {
    const row = await this.db.localServiceContact.findUnique({
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

  async removeContact(
    categoryId: string,
    contactId: string,
    adminId: string,
    correlationId?: string,
  ) {
    const existing = await this.db.localServiceContact.findUnique({
      where: { id: contactId },
      select: {
        id: true,
        categoryId: true,
        name: true,
        phone: true,
        photoStoragePath: true,
      },
    });
    if (!existing || existing.categoryId !== categoryId) {
      throw new AppError('not_found', 'Contact not found', 404);
    }

    if (existing.photoStoragePath) {
      await unlink(existing.photoStoragePath).catch(() => undefined);
    }

    await this.db.localServiceContact.delete({ where: { id: contactId } });
    await this.audit.record({
      action: 'local_service.contact_removed',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'local_service_contact',
      resourceId: contactId,
      correlationId,
      metadata: { name: existing.name, phone: existing.phone },
    });
  }

  private async uniqueSlug(name: string): Promise<string> {
    const base = slugify(name);
    let slug = base;
    for (let n = 2; n <= 50; n += 1) {
      const taken = await this.db.localServiceCategory.findUnique({
        where: { slug },
        select: { id: true },
      });
      if (!taken) return slug;
      slug = `${base}-${n}`.slice(0, 60);
    }
    throw new AppError('conflict', 'Choose a different service name', 409);
  }
}
