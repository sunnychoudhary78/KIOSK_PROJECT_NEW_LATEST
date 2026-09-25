import { describe, expect, it, vi } from 'vitest';
import { DeviceStatus } from '@prisma/client';
import { DevicesService } from '../src/modules/devices/devices.service.js';
import { setDevicePrintLimitsSchema } from '../src/modules/devices/devices.schemas.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

const limits = {
  maxPagesPerSession: 8,
  freePagesPerSession: 2,
  extraPageChargeRupees: 15,
  freeColorPagesPerSession: 1,
  extraColorPageChargeRupees: 25,
};

function deviceRow() {
  return {
    id: deviceId,
    name: 'Lobby',
    deviceKey: 'dk_test',
    status: DeviceStatus.active,
    latitude: 28.6,
    longitude: 77.2,
    address: null,
    lastHeartbeatAt: null,
    surveillanceEnabled: false,
    ...limits,
    site: { name: 'HQ' },
  };
}

describe('setDevicePrintLimitsSchema', () => {
  it('rejects free pages above the hard session cap', () => {
    const result = setDevicePrintLimitsSchema.safeParse({
      ...limits,
      freePagesPerSession: 20,
      maxPagesPerSession: 8,
    });
    expect(result.success).toBe(false);
  });

  it('rejects color free pages above the hard session cap', () => {
    const result = setDevicePrintLimitsSchema.safeParse({
      ...limits,
      freeColorPagesPerSession: 20,
      maxPagesPerSession: 8,
    });
    expect(result.success).toBe(false);
  });

  it('accepts valid limits', () => {
    expect(setDevicePrintLimitsSchema.parse(limits)).toEqual(limits);
  });
});

describe('DevicesService.setPrintLimits', () => {
  it('updates kiosk print limits and audits', async () => {
    const row = deviceRow();
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          ...row,
          ...data,
        })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    const result = await service.setPrintLimits(deviceId, limits, 'admin-1', 'corr');
    expect(result).toMatchObject(limits);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'device.print_limits_updated',
        principalId: 'admin-1',
        resourceId: deviceId,
        metadata: limits,
      }),
    );
  });

  it('maps print limits on list items', async () => {
    const db = {
      device: {
        findMany: vi.fn(async () => [deviceRow()]),
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
    );
    const result = await service.list();
    expect(result.items[0]).toMatchObject({
      id: deviceId,
      ...limits,
    });
  });
});
