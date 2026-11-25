import { describe, expect, it, vi } from 'vitest';
import { DeviceStatus } from '@prisma/client';
import { DevicesService } from '../src/modules/devices/devices.service.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const tenantId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const siteId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

function deviceRow() {
  return {
    id: deviceId,
    tenantId,
    siteId,
    name: 'Lobby',
    deviceKey: 'dk_existing_key',
    deviceSecretHash: 'old-hash',
    status: DeviceStatus.active,
    latitude: 28.6,
    longitude: 77.2,
    address: null,
    lastHeartbeatAt: null,
    surveillanceEnabled: false,
    site: { id: siteId, name: 'HQ' },
  };
}

/** Enough for mapDeviceWithTray → getTrayCapacity / getActiveAppVersion. */
function deviceDtoDbExtras() {
  return {
    printJob: {
      aggregate: vi.fn(async () => ({ _sum: { pagesExpected: 0 } })),
    },
    kioskAppRelease: {
      findFirst: vi.fn(async () => null),
    },
  };
}

describe('DevicesService.getCredentials', () => {
  it('returns the stored secret without rotating', async () => {
    const row = {
      ...deviceRow(),
      deviceSecret: 'ds_stored_secret_value_12345678',
    };
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(),
      },
      ...deviceDtoDbExtras(),
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    const result = await service.getCredentials(deviceId, 'admin-1');

    expect(result.deviceKey).toBe('dk_existing_key');
    expect(result.deviceSecret).toBe('ds_stored_secret_value_12345678');
    expect(db.device.update).not.toHaveBeenCalled();
    expect(audit.record).not.toHaveBeenCalled();
  });
});

describe('DevicesService.rotateSecret', () => {
  it('issues a new secret once and keeps the same device key', async () => {
    const row = deviceRow();
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...row,
      ...data,
    }));
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update,
      },
      ...deviceDtoDbExtras(),
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    const result = await service.rotateSecret(deviceId, 'admin-1', 'corr-1');

    expect(result.deviceKey).toBe('dk_existing_key');
    expect(result.deviceSecret).toMatch(/^ds_[a-f0-9]+$/);
    expect(update).toHaveBeenCalledOnce();
    expect(update.mock.calls[0]?.[0]?.data?.deviceSecret).toBe(result.deviceSecret);
    expect(update.mock.calls[0]?.[0]?.data?.deviceSecretHash).toEqual(expect.any(String));
    expect(update.mock.calls[0]?.[0]?.data?.deviceSecretHash).not.toBe(result.deviceSecret);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'device.secret_rotated',
        resourceId: deviceId,
        principalId: 'admin-1',
      }),
    );
  });

  it('throws not_found when device is missing', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => null),
        update: vi.fn(),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    await expect(service.rotateSecret(deviceId, 'admin-1')).rejects.toMatchObject({
      code: 'not_found',
    });
    expect(db.device.update).not.toHaveBeenCalled();
  });
});
