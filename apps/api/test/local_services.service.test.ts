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

const contactSelect = {
  id: true,
  name: true,
  phone: true,
  sortOrder: true,
  rating: true,
  pinned: true,
  address: true,
  latitude: true,
  longitude: true,
  photoStoragePath: true,
};

describe('LocalServicesService.list', () => {
  it('returns categories and contacts for admin without geo filter', async () => {
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
            latitude: 28.61,
            longitude: 77.2,
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
          select: contactSelect,
        },
      },
    });
    expect(result.categories[0]?.contacts[0]).toMatchObject({
      phone: '9871471035',
      rating: 4.5,
      pinned: true,
      address: 'Gate 2',
      latitude: 28.61,
      longitude: 77.2,
      distanceKm: null,
      photoUrl: null,
    });
  });

  it('filters device list to contacts within 5 km of the kiosk', async () => {
    const findMany = vi.fn(async () => [
      {
        id: 'cat-1',
        slug: 'plumber',
        name: 'Plumber',
        sortOrder: 1,
        isActive: true,
        contacts: [
          {
            id: 'near',
            name: 'Near Shop',
            phone: '9999999999',
            sortOrder: 1,
            rating: 3,
            pinned: false,
            address: 'Near',
            latitude: 28.6139,
            longitude: 77.209,
            photoStoragePath: null,
          },
          {
            id: 'far',
            name: 'Far Shop',
            phone: '8888888888',
            sortOrder: 2,
            rating: 5,
            pinned: true,
            address: 'Far',
            // ~20+ km away from origin
            latitude: 28.8,
            longitude: 77.5,
            photoStoragePath: null,
          },
        ],
      },
    ]);
    const { service } = serviceWith({
      localServiceCategory: { findMany },
      device: {
        findUnique: vi.fn(async () => ({ latitude: 28.6139, longitude: 77.209 })),
      },
    });

    const result = await service.list('device-1');
    expect(result.radiusKm).toBe(5);
    expect(result.categories).toHaveLength(1);
    expect(result.categories[0]?.contacts.map((c) => c.id)).toEqual(['near']);
    expect(result.categories[0]?.contacts[0]?.distanceKm).toBe(0);
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

describe('LocalServicesService.nearby', () => {
  it('returns providers near the citizen GPS within radius', async () => {
    const findMany = vi.fn(async () => [
      {
        id: 'cat-1',
        slug: 'electrician',
        name: 'Electrician',
        sortOrder: 1,
        isActive: true,
        contacts: [
          {
            id: 'near',
            name: 'Local Elec',
            phone: '9111111111',
            sortOrder: 1,
            rating: 4,
            pinned: false,
            address: 'A',
            latitude: 19.076,
            longitude: 72.8777,
            photoStoragePath: null,
          },
          {
            id: 'no-geo',
            name: 'No Geo',
            phone: '9222222222',
            sortOrder: 2,
            rating: 5,
            pinned: true,
            address: 'B',
            latitude: null,
            longitude: null,
            photoStoragePath: null,
          },
        ],
      },
    ]);
    const { service } = serviceWith({ localServiceCategory: { findMany } });
    const result = await service.nearby({ lat: 19.076, lng: 72.8777, radiusKm: 5 });
    expect(result.categories[0]?.contacts).toHaveLength(1);
    expect(result.categories[0]?.contacts[0]?.id).toBe('near');
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
      latitude: 28.6,
      longitude: 77.2,
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

    const contact = await service.createContact(
      'cat-1',
      { name: 'Ravi', phone: '9876543210', latitude: 28.6, longitude: 77.2 },
      'admin-1',
    );
    expect(contact.phone).toBe('9876543210');
    expect(contact.latitude).toBe(28.6);

    await service.removeContact('cat-1', 'contact-1', 'admin-1');
    expect(deleteContact).toHaveBeenCalledWith({ where: { id: 'contact-1' } });

    await service.removeCategory('cat-1', 'admin-1');
    expect(deleteCategory).toHaveBeenCalledWith({ where: { id: 'cat-1' } });
    expect(audit.record).toHaveBeenCalledTimes(4);
  });

  it('updates rating, pin, address and coords', async () => {
    const existing = {
      id: 'contact-1',
      categoryId: 'cat-1',
      name: 'Ravi',
      phone: '9876543210',
      sortOrder: 1,
      rating: 0,
      pinned: false,
      address: null,
      latitude: null,
      longitude: null,
      photoStoragePath: null,
    };
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...existing,
      ...data,
      rating: 5,
      pinned: true,
      address: 'Lobby shop',
      latitude: 28.61,
      longitude: 77.21,
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
      {
        rating: 5,
        pinned: true,
        address: 'Lobby shop',
        latitude: 28.61,
        longitude: 77.21,
      },
      'admin-1',
    );

    expect(result).toMatchObject({
      rating: 5,
      pinned: true,
      address: 'Lobby shop',
      latitude: 28.61,
      longitude: 77.21,
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
