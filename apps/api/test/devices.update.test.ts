import { describe, expect, it, vi } from 'vitest';
import { DeviceStatus } from '@prisma/client';
import { DevicesService } from '../src/modules/devices/devices.service.js';
import { updateDeviceSchema } from '../src/modules/devices/devices.schemas.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const tenantId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const oldSiteId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const newSiteId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

function deviceRow() {
  return {
    id: deviceId,
    tenantId,
    siteId: oldSiteId,
    name: 'Lobby',
    deviceKey: 'dk_test',
    status: DeviceStatus.active,
    latitude: 28.6,
    longitude: 77.2,
    address: 'Old address',
    lastHeartbeatAt: null,
    surveillanceEnabled: false,
    site: { id: oldSiteId, name: 'HQ' },
  };
}

describe('updateDeviceSchema', () => {
  it('accepts a full identity payload', () => {
    const parsed = updateDeviceSchema.safeParse({
      name: 'Lobby Kiosk',
      siteName: 'Demo Site',
      latitude: 28.6139,
      longitude: 77.209,
      address: 'City Mall',
    });
    expect(parsed.success).toBe(true);
  });

  it('rejects out-of-range coordinates', () => {
    const parsed = updateDeviceSchema.safeParse({
      name: 'Lobby Kiosk',
      siteName: 'Demo Site',
      latitude: 120,
      longitude: 77.209,
    });
    expect(parsed.success).toBe(false);
  });
});

describe('DevicesService.updateDetails', () => {
  it('updates name, site, coords, address and audits before/after', async () => {
    const row = deviceRow();
    const newSite = { id: newSiteId, tenantId, name: 'Airport' };
    const findFirst = vi.fn(async () => null);
    const createSite = vi.fn(async () => newSite);
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...row,
      ...data,
      site: newSite,
    }));
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update,
      },
      site: {
        findFirst,
        create: createSite,
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    const result = await service.updateDetails(
      deviceId,
      {
        name: 'Gate A Kiosk',
        siteName: 'Airport',
        latitude: 28.5562,
        longitude: 77.1,
        address: 'T3 Departures',
      },
      'admin-1',
      'corr',
    );

    expect(findFirst).toHaveBeenCalledWith({
      where: { tenantId, name: 'Airport' },
    });
    expect(createSite).toHaveBeenCalledWith({
      data: { tenantId, name: 'Airport' },
    });
    expect(update).toHaveBeenCalledWith({
      where: { id: deviceId },
      data: {
        name: 'Gate A Kiosk',
        siteId: newSiteId,
        latitude: 28.5562,
        longitude: 77.1,
        address: 'T3 Departures',
      },
      include: { site: true },
    });
    expect(result.name).toBe('Gate A Kiosk');
    expect(result.siteName).toBe('Airport');
    expect(result.latitude).toBe(28.5562);
    expect(result.longitude).toBe(77.1);
    expect(result.address).toBe('T3 Departures');
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'device.updated',
        principalId: 'admin-1',
        resourceId: deviceId,
        correlationId: 'corr',
        metadata: {
          before: {
            name: 'Lobby',
            siteName: 'HQ',
            latitude: 28.6,
            longitude: 77.2,
            address: 'Old address',
          },
          after: {
            name: 'Gate A Kiosk',
            siteName: 'Airport',
            latitude: 28.5562,
            longitude: 77.1,
            address: 'T3 Departures',
          },
        },
      }),
    );
  });

  it('reuses an existing site when the name already exists', async () => {
    const row = deviceRow();
    const existingSite = { id: newSiteId, tenantId, name: 'Airport' };
    const createSite = vi.fn();
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          ...row,
          ...data,
          site: existingSite,
        })),
      },
      site: {
        findFirst: vi.fn(async () => existingSite),
        create: createSite,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );

    await service.updateDetails(
      deviceId,
      {
        name: 'Gate A Kiosk',
        siteName: 'Airport',
        latitude: 28.5562,
        longitude: 77.1,
      },
      'admin-1',
    );

    expect(createSite).not.toHaveBeenCalled();
    expect(db.device.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ siteId: newSiteId, address: null }),
      }),
    );
  });

  it('returns 404 when the device is missing', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => null),
        update: vi.fn(),
      },
      site: {
        findFirst: vi.fn(),
        create: vi.fn(),
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );

    await expect(
      service.updateDetails(
        deviceId,
        {
          name: 'Gate A Kiosk',
          siteName: 'Airport',
          latitude: 28.5562,
          longitude: 77.1,
        },
        'admin-1',
      ),
    ).rejects.toMatchObject({ code: 'not_found', statusCode: 404 });
    expect(db.device.update).not.toHaveBeenCalled();
  });
});
