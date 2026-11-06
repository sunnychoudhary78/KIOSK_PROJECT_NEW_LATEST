import { describe, expect, it, vi } from 'vitest';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import { LocalServicesService } from '../src/modules/local_services/local_services.service.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';

function serviceWith(db: unknown) {
  const audit = { record: vi.fn(async () => undefined) };
  return {
    audit,
    service: new LocalServicesService(db as DbClient, audit as unknown as AuditService),
  };
}

describe('LocalServicesService.list', () => {
  it('returns categories and contacts in sort order', async () => {
    const findMany = vi.fn(async () => [
      {
        id: 'cat-1',
        slug: 'tailor',
        name: 'Tailor',
        sortOrder: 1,
        contacts: [{ id: 'c-1', name: 'Abdul Kalam', phone: '9871471035', sortOrder: 1 }],
      },
    ]);
    const { service } = serviceWith({ localServiceCategory: { findMany } });
    const result = await service.list();
    expect(findMany).toHaveBeenCalledWith({
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
    expect(result.categories[0]?.name).toBe('Tailor');
    expect(result.categories[0]?.contacts[0]?.phone).toBe('9871471035');
  });
});

describe('LocalServicesService writes', () => {
  it('creates a service and a 10-digit contact, then removes both', async () => {
    const findCategory = vi
      .fn()
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ id: 'cat-1', name: 'Laundry' })
      .mockResolvedValueOnce({ id: 'cat-1', name: 'Laundry', slug: 'laundry' });
    const findContact = vi.fn(async () => ({
      id: 'contact-1',
      categoryId: 'cat-1',
      name: 'Ravi',
      phone: '9876543210',
    }));
    const createCategory = vi.fn(async () => ({
      id: 'cat-1',
      slug: 'laundry',
      name: 'Laundry',
      sortOrder: 3,
    }));
    const deleteCategory = vi.fn(async () => undefined);
    const aggregateCategory = vi.fn(async () => ({ _max: { sortOrder: 2 } }));
    const aggregateContact = vi.fn(async () => ({ _max: { sortOrder: 0 } }));
    const createContact = vi.fn(async () => ({
      id: 'contact-1',
      name: 'Ravi',
      phone: '9876543210',
      sortOrder: 1,
    }));
    const deleteContact = vi.fn(async () => undefined);
    const { service, audit } = serviceWith({
      localServiceCategory: {
        findUnique: findCategory,
        create: createCategory,
        delete: deleteCategory,
        aggregate: aggregateCategory,
      },
      localServiceContact: {
        aggregate: aggregateContact,
        create: createContact,
        findUnique: findContact,
        delete: deleteContact,
      },
    });

    const created = await service.createCategory({ name: 'Laundry' }, 'admin-1');
    expect(created.slug).toBe('laundry');
    expect(createCategory).toHaveBeenCalledWith({
      data: { name: 'Laundry', slug: 'laundry', sortOrder: 3 },
      select: { id: true, slug: true, name: true, sortOrder: true },
    });

    const contact = await service.createContact(
      'cat-1',
      { name: 'Ravi', phone: '9876543210' },
      'admin-1',
    );
    expect(contact.phone).toBe('9876543210');

    await service.removeContact('cat-1', 'contact-1', 'admin-1');
    expect(deleteContact).toHaveBeenCalledWith({ where: { id: 'contact-1' } });

    await service.removeCategory('cat-1', 'admin-1');
    expect(deleteCategory).toHaveBeenCalledWith({ where: { id: 'cat-1' } });
    expect(audit.record).toHaveBeenCalledTimes(4);
  });

  it('rejects a missing service', async () => {
    const { service } = serviceWith({
      localServiceCategory: { findUnique: vi.fn(async () => null) },
    });
    await expect(service.removeCategory('missing', 'admin-1')).rejects.toMatchObject({
      code: 'not_found',
    });
  });
});
