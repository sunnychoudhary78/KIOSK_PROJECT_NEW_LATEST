import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import type {
  CreateLocalServiceCategoryBody,
  CreateLocalServiceContactBody,
} from './local_services.schemas.js';

function slugify(name: string): string {
  const base = name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
  return base || 'service';
}

export class LocalServicesService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {}

  async list() {
    const categories = await this.db.localServiceCategory.findMany({
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      select: {
        id: true,
        slug: true,
        name: true,
        sortOrder: true,
        contacts: {
          orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
          select: { id: true, name: true, phone: true, sortOrder: true },
        },
      },
    });
    return { categories };
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
      data: { name, slug, sortOrder },
      select: { id: true, slug: true, name: true, sortOrder: true },
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

  async removeCategory(id: string, adminId: string, correlationId?: string) {
    const existing = await this.db.localServiceCategory.findUnique({
      where: { id },
      select: { id: true, name: true, slug: true },
    });
    if (!existing) {
      throw new AppError('not_found', 'Service not found', 404);
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

    const row = await this.db.localServiceContact.create({
      data: {
        categoryId,
        name: input.name.trim(),
        phone: input.phone,
        sortOrder,
      },
      select: { id: true, name: true, phone: true, sortOrder: true },
    });

    await this.audit.record({
      action: 'local_service.contact_created',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'local_service_contact',
      resourceId: row.id,
      correlationId,
      metadata: { category: category.name, name: row.name, phone: row.phone },
    });

    return row;
  }

  async removeContact(
    categoryId: string,
    contactId: string,
    adminId: string,
    correlationId?: string,
  ) {
    const existing = await this.db.localServiceContact.findUnique({
      where: { id: contactId },
      select: { id: true, categoryId: true, name: true, phone: true },
    });
    if (!existing || existing.categoryId !== categoryId) {
      throw new AppError('not_found', 'Contact not found', 404);
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
