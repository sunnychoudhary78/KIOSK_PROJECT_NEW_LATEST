import { describe, expect, it, vi } from 'vitest';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { ServicesCatalogService } from '../src/modules/services/services.service.js';
import { AppError } from '../src/shared/errors.js';

describe('ServicesCatalogService', () => {
  const serviceRow = {
    id: 'svc-1',
    code: 'well_being',
    name: 'Well Being',
    description: 'Health checks',
    isActive: true,
  };

  it('listForDevice without deviceId marks every catalog item enabled', async () => {
    const db = {
      platformService: {
        findMany: vi.fn(async () => [serviceRow]),
      },
      serviceEnablement: {
        findMany: vi.fn(),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new ServicesCatalogService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    const result = await service.listForDevice();
    expect(db.serviceEnablement.findMany).not.toHaveBeenCalled();
    expect(result.items).toEqual([
      {
        code: 'well_being',
        name: 'Well Being',
        description: 'Health checks',
        enabled: true,
      },
    ]);
  });

  it('listForDevice treats a missing enablement row as disabled', async () => {
    const db = {
      platformService: {
        findMany: vi.fn(async () => [serviceRow]),
      },
      serviceEnablement: {
        findMany: vi.fn(async () => []),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new ServicesCatalogService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    const result = await service.listForDevice('device-1');
    expect(result.items[0]?.enabled).toBe(false);
  });

  it('setEnablement upserts and audits', async () => {
    const db = {
      platformService: {
        findUnique: vi.fn(async () => serviceRow),
      },
      device: {
        findUnique: vi.fn(async () => ({ id: 'device-1', tenantId: 'tenant-1' })),
      },
      serviceEnablement: {
        upsert: vi.fn(async () => ({
          deviceId: 'device-1',
          enabled: false,
        })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new ServicesCatalogService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    const result = await service.setEnablement(
      'well_being',
      { deviceId: 'device-1', enabled: false },
      'admin-1',
      'corr-1',
    );

    expect(result).toEqual({
      code: 'well_being',
      deviceId: 'device-1',
      enabled: false,
    });
    expect(db.serviceEnablement.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        update: { enabled: false },
        create: expect.objectContaining({
          tenantId: 'tenant-1',
          deviceId: 'device-1',
          serviceId: 'svc-1',
          enabled: false,
        }),
      }),
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'service.enablement_updated',
        metadata: { serviceCode: 'well_being', deviceId: 'device-1', enabled: false },
      }),
    );
  });

  it('assertEnabled throws service_disabled when enablement is off', async () => {
    const db = {
      platformService: {
        findUnique: vi.fn(async () => serviceRow),
      },
      serviceEnablement: {
        findUnique: vi.fn(async () => ({ enabled: false })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new ServicesCatalogService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    await expect(service.assertEnabled('device-1', 'well_being')).rejects.toMatchObject({
      code: 'service_disabled',
      statusCode: 403,
    } satisfies Partial<AppError>);
  });

  it('assertEnabled allows an enabled service', async () => {
    const db = {
      platformService: {
        findUnique: vi.fn(async () => serviceRow),
      },
      serviceEnablement: {
        findUnique: vi.fn(async () => ({ enabled: true })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new ServicesCatalogService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    await expect(service.assertEnabled('device-1', 'well_being')).resolves.toBeUndefined();
  });
});
