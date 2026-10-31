import { describe, expect, it, vi } from 'vitest';
import { DeviceStatus } from '@prisma/client';
import { DevicesService } from '../src/modules/devices/devices.service.js';
import { setPrinterTraySchema } from '../src/modules/devices/devices.schemas.js';
import { applyTrayLoad, pagesLeft, usbPagesTotal } from '../src/modules/devices/printer_tray.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { AppError } from '../src/shared/errors.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

function deviceRow(overrides: Record<string, unknown> = {}) {
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
    maxPagesPerSession: 10,
    freePagesPerSession: 5,
    extraPageChargeRupees: 10,
    freeColorPagesPerSession: 0,
    extraColorPageChargeRupees: 20,
    printerHealth: {
      state: 'ready',
      online: true,
      maintenance: { available: true, pages: { total: 250 } },
    },
    trayPages: null as number | null,
    trayBaselinePages: null as number | null,
    site: { name: 'HQ' },
    ...overrides,
  };
}

describe('tray pages left', () => {
  it('reads the USB lifetime total', () => {
    expect(usbPagesTotal({ maintenance: { pages: { total: 250 } } })).toBe(250);
    expect(usbPagesTotal({ state: 'ready' })).toBeNull();
    expect(usbPagesTotal(null)).toBeNull();
  });

  it('subtracts only the rise since the baseline and floors at 0', () => {
    expect(pagesLeft(null, null, 250)).toBeNull();
    expect(pagesLeft(100, 250, null)).toBeNull();
    expect(pagesLeft(100, 250, 254)).toBe(96);
    expect(pagesLeft(100, 250, 400)).toBe(0);
    expect(pagesLeft(100, 250, 240)).toBe(100);
  });

  it('adds onto the leftover and replace discards it', () => {
    expect(
      applyTrayLoad({
        mode: 'add',
        pages: 50,
        trayPages: 100,
        trayBaselinePages: 250,
        usbTotal: 254,
      }),
    ).toEqual({ trayPages: 146, trayBaselinePages: 254 });
    expect(
      applyTrayLoad({
        mode: 'add',
        pages: 100,
        trayPages: null,
        trayBaselinePages: null,
        usbTotal: 250,
      }),
    ).toEqual({ trayPages: 100, trayBaselinePages: 250 });
    expect(
      applyTrayLoad({
        mode: 'replace',
        pages: 500,
        trayPages: 100,
        trayBaselinePages: 250,
        usbTotal: 254,
      }),
    ).toEqual({ trayPages: 500, trayBaselinePages: 254 });
  });

  it('rejects a page count outside 1 to 2000', () => {
    expect(setPrinterTraySchema.safeParse({ mode: 'add', pages: 0 }).success).toBe(false);
    expect(setPrinterTraySchema.safeParse({ mode: 'replace', pages: 2001 }).success).toBe(false);
    expect(setPrinterTraySchema.parse({ mode: 'add', pages: 100 })).toEqual({
      mode: 'add',
      pages: 100,
    });
  });
});

describe('DevicesService.setPrinterTray', () => {
  function serviceFor(row: ReturnType<typeof deviceRow>) {
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
    return {
      audit,
      db,
      service: new DevicesService(db as unknown as DbClient, audit as unknown as AuditService),
    };
  }

  it('adds onto the pages still left', async () => {
    const { service, audit } = serviceFor(
      deviceRow({
        trayPages: 100,
        trayBaselinePages: 250,
        printerHealth: {
          state: 'ready',
          online: true,
          maintenance: { available: true, pages: { total: 254 } },
        },
      }),
    );
    const result = await service.setPrinterTray(
      deviceId,
      { mode: 'add', pages: 50 },
      'admin-1',
      'corr',
    );
    expect(result.trayPages).toBe(146);
    expect(result.trayBaselinePages).toBe(254);
    expect(result.pagesLeft).toBe(146);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'device.printer_tray_updated',
        metadata: {
          mode: 'add',
          pages: 50,
          trayPages: 146,
          trayBaselinePages: 254,
        },
      }),
    );
  });

  it('replace discards the previous leftover', async () => {
    const { service } = serviceFor(
      deviceRow({
        trayPages: 96,
        trayBaselinePages: 250,
        printerHealth: {
          state: 'ready',
          online: true,
          maintenance: { available: true, pages: { total: 254 } },
        },
      }),
    );
    const result = await service.setPrinterTray(deviceId, { mode: 'replace', pages: 500 }, 'admin-1');
    expect(result.trayPages).toBe(500);
    expect(result.trayBaselinePages).toBe(254);
    expect(result.pagesLeft).toBe(500);
  });

  it('rejects the save when the USB page total is missing', async () => {
    const { service, db } = serviceFor(deviceRow({ printerHealth: { state: 'ready', online: true } }));
    await expect(
      service.setPrinterTray(deviceId, { mode: 'add', pages: 100 }, 'admin-1'),
    ).rejects.toMatchObject({
      code: 'printer_page_total_unavailable',
      statusCode: 409,
    } satisfies Partial<AppError>);
    expect(db.device.update).not.toHaveBeenCalled();
  });
});
