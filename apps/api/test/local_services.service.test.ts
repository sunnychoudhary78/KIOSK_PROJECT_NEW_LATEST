import { describe, expect, it, vi } from 'vitest';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import { LocalServicesService } from '../src/modules/local_services/local_services.service.js';

describe('LocalServicesService.list', () => {
  it('returns categories and contacts in sort order', async () => {
    const findMany = vi.fn(async () => [
      {
        slug: 'tailor',
        name: 'Tailor',
        contacts: [{ name: 'Abdul Kalam', phone: '9871471035' }],
      },
    ]);
    const db = {
      localServiceCategory: { findMany },
    };
    const service = new LocalServicesService(db as unknown as DbClient);
    const result = await service.list();
    expect(findMany).toHaveBeenCalledWith({
      orderBy: { sortOrder: 'asc' },
      select: {
        slug: true,
        name: true,
        contacts: {
          orderBy: { sortOrder: 'asc' },
          select: { name: true, phone: true },
        },
      },
    });
    expect(result.categories[0]?.name).toBe('Tailor');
    expect(result.categories[0]?.contacts[0]?.phone).toBe('9871471035');
  });
});
