import type { DbClient } from '../../infrastructure/database/prisma.js';

export class LocalServicesService {
  constructor(private readonly db: DbClient) {}

  async list() {
    const categories = await this.db.localServiceCategory.findMany({
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
    return { categories };
  }
}
