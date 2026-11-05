import { describe, expect, it, vi } from 'vitest';
import { PrintJobStatus } from '@prisma/client';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import { AppError, isAppError } from '../src/shared/errors.js';
import {
  assertTrayCapacity,
  getTrayCapacity,
} from '../src/modules/printing/tray_capacity.js';

const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

function mockDb(input: {
  trayPages: number | null;
  trayBaselinePages: number | null;
  usbTotal: number | null;
  reserved?: number;
}): DbClient {
  return {
    device: {
      findUnique: vi.fn(async () => ({
        trayPages: input.trayPages,
        trayBaselinePages: input.trayBaselinePages,
        printerHealth:
          input.usbTotal == null
            ? { state: 'ready' }
            : { maintenance: { pages: { total: input.usbTotal } } },
      })),
    },
    printJob: {
      aggregate: vi.fn(async () => ({
        _sum: { pagesExpected: input.reserved ?? 0 },
      })),
    },
  } as unknown as DbClient;
}

describe('getTrayCapacity', () => {
  it('returns available null when tray is not configured', async () => {
    const snap = await getTrayCapacity(
      mockDb({ trayPages: null, trayBaselinePages: null, usbTotal: 100 }),
      deviceId,
    );
    expect(snap.pagesLeft).toBeNull();
    expect(snap.available).toBeNull();
  });

  it('subtracts reserved open-job pages', async () => {
    const snap = await getTrayCapacity(
      mockDb({
        trayPages: 100,
        trayBaselinePages: 250,
        usbTotal: 254, // used 4 → left 96
        reserved: 8,
      }),
      deviceId,
    );
    expect(snap.pagesLeft).toBe(96);
    expect(snap.reserved).toBe(8);
    expect(snap.available).toBe(88);
  });
});

describe('assertTrayCapacity', () => {
  it('allows when pagesLeft is null', async () => {
    await expect(
      assertTrayCapacity(
        mockDb({ trayPages: null, trayBaselinePages: null, usbTotal: null }),
        deviceId,
        50,
      ),
    ).resolves.toBeUndefined();
  });

  it('rejects when job needs more than pages left', async () => {
    const db = mockDb({
      trayPages: 5,
      trayBaselinePages: 100,
      usbTotal: 100, // left 5
      reserved: 0,
    });
    try {
      await assertTrayCapacity(db, deviceId, 6);
      expect.fail('expected AppError');
    } catch (error) {
      expect(isAppError(error)).toBe(true);
      if (isAppError(error)) {
        expect(error.code).toBe('insufficient_tray_pages');
        expect(error.statusCode).toBe(409);
        expect(error.message).toContain('Only 5 pages left');
      }
    }
  });

  it('rejects when reserved pages leave too little room', async () => {
    const db = mockDb({
      trayPages: 10,
      trayBaselinePages: 100,
      usbTotal: 100, // left 10
      reserved: 8,
    });
    await expect(assertTrayCapacity(db, deviceId, 3)).rejects.toBeInstanceOf(AppError);
    await expect(assertTrayCapacity(db, deviceId, 2)).resolves.toBeUndefined();
  });

  it('queries only open job statuses for reservation', async () => {
    const db = mockDb({
      trayPages: 10,
      trayBaselinePages: 100,
      usbTotal: 100,
      reserved: 0,
    });
    await assertTrayCapacity(db, deviceId, 1);
    expect(db.printJob.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          deviceId,
          status: {
            in: [PrintJobStatus.created, PrintJobStatus.ready, PrintJobStatus.printing],
          },
        },
      }),
    );
  });
});
