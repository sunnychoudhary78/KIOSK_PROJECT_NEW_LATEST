import { describe, expect, it, vi } from 'vitest';
import { DeviceStatus } from '@prisma/client';
import { DevicesService } from '../src/modules/devices/devices.service.js';
import { deviceHeartbeatBodySchema } from '../src/modules/devices/devices.schemas.js';
import { assertActiveDevice } from '../src/shared/device-guard.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import type { NextFunction, Request, Response } from 'express';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

function deviceRow(status: DeviceStatus) {
  return {
    id: deviceId,
    name: 'Lobby',
    deviceKey: 'dk_test',
    status,
    latitude: 28.6,
    longitude: 77.2,
    address: null,
    lastHeartbeatAt: null,
    surveillanceEnabled: false,
    site: { name: 'HQ' },
  };
}

describe('DevicesService.setStatus', () => {
  it('marks a kiosk inactive and audits deactivation', async () => {
    const row = deviceRow(DeviceStatus.active);
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async ({ data }: { data: { status: DeviceStatus } }) => ({
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
    const result = await service.setStatus(deviceId, 'inactive', 'admin-1', 'corr');
    expect(result.status).toBe(DeviceStatus.inactive);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'device.deactivated',
        principalId: 'admin-1',
        resourceId: deviceId,
      }),
    );
  });

  it('starts a stopped kiosk', async () => {
    const row = deviceRow(DeviceStatus.inactive);
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async ({ data }: { data: { status: DeviceStatus } }) => ({
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
    const result = await service.setStatus(deviceId, 'active', 'admin-1');
    expect(result.status).toBe(DeviceStatus.active);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'device.activated' }),
    );
  });
});

describe('DevicesService.setSurveillance', () => {
  it('starts surveillance and audits', async () => {
    const row = deviceRow(DeviceStatus.active);
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async ({ data }: { data: { surveillanceEnabled: boolean } }) => ({
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
    const result = await service.setSurveillance(deviceId, true, 'admin-1', 'corr');
    expect(result.surveillanceEnabled).toBe(true);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'device.surveillance_started',
        principalId: 'admin-1',
        resourceId: deviceId,
      }),
    );
  });

  it('stops surveillance and audits', async () => {
    const row = { ...deviceRow(DeviceStatus.active), surveillanceEnabled: true };
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async ({ data }: { data: { surveillanceEnabled: boolean } }) => ({
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
    const result = await service.setSurveillance(deviceId, false, 'admin-1');
    expect(result.surveillanceEnabled).toBe(false);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'device.surveillance_stopped' }),
    );
  });
});

describe('DevicesService.heartbeat', () => {
  it('does not resurrect an inactive device', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => deviceRow(DeviceStatus.inactive)),
        update: vi.fn(),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );
    await expect(service.heartbeat(deviceId, deviceId)).rejects.toMatchObject({
      code: 'device_inactive',
      statusCode: 403,
    });
    expect(db.device.update).not.toHaveBeenCalled();
  });

  it('updates lastHeartbeatAt without flipping an already-active device', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => deviceRow(DeviceStatus.active)),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          ...deviceRow(DeviceStatus.active),
          ...data,
        })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );
    await service.heartbeat(deviceId, deviceId);
    expect(db.device.update).toHaveBeenCalledWith({
      where: { id: deviceId },
      data: { lastHeartbeatAt: expect.any(Date) },
    });
    expect(audit.record).not.toHaveBeenCalled();
  });

  it('returns the surveillance flag', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          ...deviceRow(DeviceStatus.active),
          surveillanceEnabled: true,
        })),
        update: vi.fn(async () => ({
          ...deviceRow(DeviceStatus.active),
          surveillanceEnabled: true,
        })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );
    await expect(service.heartbeat(deviceId, deviceId)).resolves.toEqual({
      surveillanceEnabled: true,
      printingPausedReason: null,
    });
  });

  it('persists surveillance health from the heartbeat body', async () => {
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...deviceRow(DeviceStatus.active),
      ...data,
    }));
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          ...deviceRow(DeviceStatus.active),
          surveillanceEnabled: true,
        })),
        update,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );
    const health = {
      state: 'camera_error' as const,
      recording: false,
      queuePending: 2,
      lastErrorCode: 'CAMERA_ERROR',
    };
    await service.heartbeat(deviceId, deviceId, { surveillance: health });
    expect(update).toHaveBeenCalledWith({
      where: { id: deviceId },
      data: {
        lastHeartbeatAt: expect.any(Date),
        surveillanceHealth: health,
        surveillanceHealthAt: expect.any(Date),
      },
    });
  });

  it('persists printer health from the heartbeat body', async () => {
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...deviceRow(DeviceStatus.active),
      ...data,
    }));
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          ...deviceRow(DeviceStatus.active),
          surveillanceEnabled: false,
        })),
        update,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );
    const printer = {
      state: 'jam' as const,
      online: true,
      printerName: 'Brother HL-L3280CDW',
      model: 'Brother HL-L3280CDW',
      pageCounter: 12045,
      snmpOk: true,
      trays: [{ name: 'Tray 1', levelPercent: 40, status: 'ok' }],
      supplies: [{ name: 'Black Toner', color: 'black', levelPercent: 55 }],
      lastErrorCode: 'PAPER_JAM',
    };
    await service.heartbeat(deviceId, deviceId, { printer });
    expect(update).toHaveBeenCalledWith({
      where: { id: deviceId },
      data: {
        lastHeartbeatAt: expect.any(Date),
        printerHealth: printer,
        printerHealthAt: expect.any(Date),
      },
    });
  });

  it('persists verified Brother maintenance without changing the page counter field', async () => {
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...deviceRow(DeviceStatus.active),
      ...data,
    }));
    const db = {
      device: {
        findUnique: vi.fn(async () => deviceRow(DeviceStatus.active)),
        update,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );
    const maintenance = {
      available: true,
      toner: { blackPercent: 90, cyanPercent: 100, magentaPercent: 100, yellowPercent: 100 },
      pages: { total: 64, color: 47, blackAndWhite: 17 },
      parts: { beltRemainingPages: 49882, fuserRemainingPages: 49936 },
    };
    const printer = {
      state: 'ready' as const,
      online: true,
      pageCounter: 64,
      maintenance,
    };
    await service.heartbeat(deviceId, deviceId, { printer });
    expect(update).toHaveBeenCalledWith({
      where: { id: deviceId },
      data: {
        lastHeartbeatAt: expect.any(Date),
        printerHealth: printer,
        printerHealthAt: expect.any(Date),
      },
    });
  });

  it('stores a printer refresh request', async () => {
    const update = vi.fn(async ({ data }: { data: { printerRefreshRequestedAt: Date } }) => ({
      ...deviceRow(DeviceStatus.active),
      ...data,
    }));
    const db = {
      device: {
        findUnique: vi.fn(async () => deviceRow(DeviceStatus.active)),
        update,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );
    const result = await service.requestPrinterRefresh(deviceId);
    expect(Date.parse(result.requestedAt)).not.toBeNaN();
    expect(update).toHaveBeenCalledWith({
      where: { id: deviceId },
      data: { printerRefreshRequestedAt: expect.any(Date) },
    });
  });

  it('clears the refresh request only when the heartbeat acks that timestamp', async () => {
    const requestedAt = new Date('2026-10-27T07:00:00.000Z');
    const update = vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      ...deviceRow(DeviceStatus.active),
      printerRefreshRequestedAt: requestedAt,
      ...data,
    }));
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          ...deviceRow(DeviceStatus.active),
          printerRefreshRequestedAt: requestedAt,
        })),
        update,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );
    const printer = { state: 'ready' as const, online: true, snmpOk: true };
    await service.heartbeat(deviceId, deviceId, { printer });
    expect(update).toHaveBeenLastCalledWith({
      where: { id: deviceId },
      data: {
        lastHeartbeatAt: expect.any(Date),
        printerHealth: printer,
        printerHealthAt: expect.any(Date),
      },
    });

    await service.heartbeat(deviceId, deviceId, {
      printer,
      printerRefreshAck: requestedAt.toISOString(),
    });
    expect(update).toHaveBeenLastCalledWith({
      where: { id: deviceId },
      data: {
        lastHeartbeatAt: expect.any(Date),
        printerHealth: printer,
        printerHealthAt: expect.any(Date),
        printerRefreshRequestedAt: null,
      },
    });
  });

  it('latches paper-out and a later ready heartbeat does not clear it', async () => {
    let paused: string | null = null;
    const update = vi.fn(async ({ data }: { data: { printingPausedReason?: string | null } }) => {
      if ('printingPausedReason' in data) paused = data.printingPausedReason ?? null;
      return { ...deviceRow(DeviceStatus.active), printingPausedReason: paused };
    });
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          ...deviceRow(DeviceStatus.active),
          printingPausedReason: paused,
        })),
        update,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );
    const paperOut = await service.heartbeat(deviceId, deviceId, {
      printer: { state: 'paper_out', noPaper: true, snmpReachable: true },
    });
    expect(paperOut.printingPausedReason).toBe('paper_out');
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ printingPausedReason: 'paper_out' }),
      }),
    );

    const ready = await service.heartbeat(deviceId, deviceId, {
      printer: { state: 'ready', noPaper: false, snmpReachable: true },
    });
    expect(ready.printingPausedReason).toBe('paper_out');
    const second = update.mock.calls[1]?.[0] as { data: Record<string, unknown> };
    expect(second.data.printingPausedReason).toBeUndefined();
  });

  it('does not latch when SNMP is unreachable or the printer is jammed', async () => {
    const update = vi.fn(async () => deviceRow(DeviceStatus.active));
    const db = {
      device: {
        findUnique: vi.fn(async () => deviceRow(DeviceStatus.active)),
        update,
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );
    await service.heartbeat(deviceId, deviceId, {
      printer: { state: 'paper_out', snmpReachable: false },
    });
    await service.heartbeat(deviceId, deviceId, {
      printer: { state: 'jam', noPaper: false, snmpReachable: true },
    });
    for (const call of update.mock.calls) {
      const data = (call[0] as { data: Record<string, unknown> }).data;
      expect(data.printingPausedReason).toBeUndefined();
    }
  });
});

describe('DevicesService.enablePrinting', () => {
  it('rejects while the latest report is still paper-out', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => ({
          ...deviceRow(DeviceStatus.active),
          printingPausedReason: 'paper_out',
          printerHealth: { state: 'paper_out', noPaper: true },
        })),
        update: vi.fn(),
      },
    };
    const service = new DevicesService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );
    await expect(service.enablePrinting(deviceId, 'admin-1')).rejects.toMatchObject({
      code: 'printer_still_out_of_paper',
      statusCode: 409,
    });
    expect(db.device.update).not.toHaveBeenCalled();
  });

  it('clears the pause when the latest report is not paper-out', async () => {
    const row = {
      ...deviceRow(DeviceStatus.active),
      printingPausedReason: 'paper_out',
      printerHealth: { state: 'ready', noPaper: false, snmpReachable: true },
    };
    const db = {
      device: {
        findUnique: vi.fn(async () => row),
        update: vi.fn(async () => ({ ...row, printingPausedReason: null })),
      },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new DevicesService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );
    const result = await service.enablePrinting(deviceId, 'admin-1', 'corr');
    expect(result.printingPausedReason).toBeNull();
    expect(db.device.update).toHaveBeenCalledWith({
      where: { id: deviceId },
      data: { printingPausedReason: null },
      include: { site: true },
    });
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'device.printing_enabled', principalId: 'admin-1' }),
    );
  });
});

describe('DevicesService.nearby', () => {
  it('omits kiosks whose printing is paused', async () => {
    const findMany = vi.fn(async () => []);
    const service = new DevicesService(
      { device: { findMany } } as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
    );
    await service.nearby({ lat: 28.6, lng: 77.2, limit: 10 });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: DeviceStatus.active,
          printingPausedReason: null,
        }),
      }),
    );
  });
});

describe('deviceHeartbeatBodySchema printer maintenance', () => {
  it('accepts a heartbeat that has no maintenance block', () => {
    const parsed = deviceHeartbeatBodySchema.safeParse({
      printer: { state: 'ready', online: true, pageCounter: 64 },
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.printer?.maintenance).toBeUndefined();
      expect(parsed.data.printer?.pageCounter).toBe(64);
    }
  });

  it('accepts verified maintenance, including a real zero', () => {
    const parsed = deviceHeartbeatBodySchema.safeParse({
      printer: {
        state: 'ready',
        online: true,
        maintenance: {
          available: true,
          toner: { blackPercent: 0, cyanPercent: 100, magentaPercent: 100, yellowPercent: 100 },
          pages: { total: 64, color: 47, blackAndWhite: 17 },
          parts: { beltRemainingPages: 49882, fuserRemainingPages: 0 },
        },
      },
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.printer?.maintenance?.toner?.blackPercent).toBe(0);
      expect(parsed.data.printer?.maintenance?.parts?.fuserRemainingPages).toBe(0);
    }
  });

  it('rejects a toner percent above 100', () => {
    const parsed = deviceHeartbeatBodySchema.safeParse({
      printer: {
        state: 'ready',
        online: true,
        maintenance: { available: true, toner: { blackPercent: 101 } },
      },
    });
    expect(parsed.success).toBe(false);
  });

  it('strips unverified maintenance fields', () => {
    const parsed = deviceHeartbeatBodySchema.safeParse({
      printer: {
        state: 'ready',
        online: true,
        maintenance: {
          available: true,
          toner: { blackPercent: 90, drumPercent: 10000 },
          jamCount: 0,
        },
      },
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.printer?.maintenance).toEqual({
        available: true,
        toner: { blackPercent: 90 },
      });
    }
  });

  it('accepts error history and an older heartbeat without it', () => {
    const legacy = deviceHeartbeatBodySchema.safeParse({
      printer: { state: 'ready', online: true, pageCounter: 64 },
    });
    expect(legacy.success).toBe(true);
    if (legacy.success) {
      expect(legacy.data.printer?.errorHistory).toBeUndefined();
    }

    const parsed = deviceHeartbeatBodySchema.safeParse({
      printer: {
        state: 'ready',
        online: true,
        errorHistory: {
          available: true,
          entries: [{ index: 1, description: 'Cannot Print ZC' }],
        },
      },
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.printer?.errorHistory?.entries).toEqual([
        { index: 1, description: 'Cannot Print ZC' },
      ]);
    }
  });

  it('rejects an eleventh error-history entry', () => {
    const entries = Array.from({ length: 11 }, (_, index) => ({
      index: 1,
      description: `Error ${index + 1}`,
    }));
    const parsed = deviceHeartbeatBodySchema.safeParse({
      printer: {
        state: 'ready',
        online: true,
        errorHistory: { available: true, entries },
      },
    });
    expect(parsed.success).toBe(false);
  });
});

describe('assertActiveDevice', () => {
  it('rejects inactive device JWTs', async () => {
    const db = {
      device: {
        findUnique: vi.fn(async () => ({ status: DeviceStatus.inactive })),
      },
    };
    const next = vi.fn() as NextFunction;
    await assertActiveDevice(db as unknown as DbClient)(
      { principal: { type: 'device', id: deviceId, deviceId } } as Request,
      {} as Response,
      next,
    );
    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ code: 'device_inactive', statusCode: 403 }),
    );
  });

  it('skips non-device principals', async () => {
    const db = { device: { findUnique: vi.fn() } };
    const next = vi.fn() as NextFunction;
    await assertActiveDevice(db as unknown as DbClient)(
      { principal: { type: 'admin', id: 'a1' } } as Request,
      {} as Response,
      next,
    );
    expect(db.device.findUnique).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledWith();
  });
});
