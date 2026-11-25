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
  it('returns categories and contacts pinned/rating first', async () => {
    const findMany = vi.fn(async () => [
      {
        id: 'cat-1',
        slug: 'tailor',
        name: 'Tailor',
        sortOrder: 1,
        isActive: true,
        contacts: [
          {
            id: 'c-1',
            name: 'Abdul Kalam',
            phone: '9871471035',
            sortOrder: 1,
            rating: 4.5,
            pinned: true,
            address: 'Gate 2',
            photoStoragePath: null,
          },
        ],
      },
    ]);
    const { service } = serviceWith({ localServiceCategory: { findMany } });
    const result = await service.list();
    expect(findMany).toHaveBeenCalledWith({
      where: { isActive: true },
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
          select: {
            id: true,
            name: true,
            phone: true,
            sortOrder: true,
            rating: true,
            pinned: true,
            address: true,
            photoStoragePath: true,
          },
        },
      },
    });
    expect(result.categories[0]?.contacts[0]).toMatchObject({
      phone: '9871471035',
      rating: 4.5,
      pinned: true,
      address: 'Gate 2',
      photoUrl: null,
    });
  });

  it('includes inactive categories when requested (admin)', async () => {
    const findMany = vi.fn(async () => []);
    const { service } = serviceWith({ localServiceCategory: { findMany } });
    await service.list(undefined, { includeInactive: true });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: undefined }),
    );
  });
});

describe('LocalServicesService writes', () => {
  it('creates a service and a 10-digit contact, then removes both', async () => {
    const findCategory = vi
      .fn()
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ id: 'cat-1', name: 'Laundry' })
      .mockResolvedValueOnce({
        id: 'cat-1',
        name: 'Laundry',
        slug: 'laundry',
        contacts: [],
      });
    const findContact = vi.fn(async () => ({
      id: 'contact-1',
      categoryId: 'cat-1',
      name: 'Ravi',
      phone: '9876543210',
      photoStoragePath: null,
    }));
    const createCategory = vi.fn(async () => ({
      id: 'cat-1',
      slug: 'laundry',
      name: 'Laundry',
      sortOrder: 3,
      isActive: true,
    }));
    const deleteCategory = vi.fn(async () => undefined);
    const aggregateCategory = vi.fn(async () => ({ _max: { sortOrder: 2 } }));
    const aggregateContact = vi.fn(async () => ({ _max: { sortOrder: 0 } }));
    const createContact = vi.fn(async () => ({
      id: 'contact-1',
      name: 'Ravi',
      phone: '9876543210',
      sortOrder: 1,
      rating: 0,
      pinned: false,
      address: null,
      photoStoragePath: null,
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
      data: { name: 'Laundry', slug: 'laundry', sortOrder: 3, isActive: true },
      select: { id: true, slug: true, name: true, sortOrder: true, isActive: true },
    });

    const contact = await service.createContact(
      'cat-1',
      { name: 'Ravi', phone: '9876543210' },
      'admin-1',
    );
    expect(contact.phone).toBe('9876543210');
    expect(contact.rating).toBe(0);
    expect(contact.pinned).toBe(false);

    await service.removeContact('cat-1', 'contact-1', 'admin-1');
    expect(deleteContact).toHaveBeenCalledWith({ where: { id: 'contact-1' } });

    await service.removeCategory('cat-1', 'admin-1');
    expect(deleteCategory).toHaveBeenCalledWith({ where: { id: 'cat-1' } });
    expect(audit.record).toHaveBeenCalledTimes(4);
  });

  it('updates rating, pin, and address', async () => {
    const existing = {
      id: 'contact-1',
      categoryId: 'cat-1',
      name: 'Ravi',
      phone: '9876543210',
      sortOrder: 1,
      rating: 0,
      pinned: false,
      address: null,
      photoStoragePath: null,
    };
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...existing,
      ...data,
      rating: 5,
      pinned: true,
      address: 'Lobby shop',
    }));
    const { service, audit } = serviceWith({
      localServiceContact: {
        findUnique: vi.fn(async () => existing),
        update,
      },
    });

    const result = await service.updateContact(
      'cat-1',
      'contact-1',
      { rating: 5, pinned: true, address: 'Lobby shop' },
      'admin-1',
    );

    expect(result).toMatchObject({
      rating: 5,
      pinned: true,
      address: 'Lobby shop',
      photoUrl: null,
    });
    expect(update).toHaveBeenCalledOnce();
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'local_service.contact_updated' }),
    );
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
