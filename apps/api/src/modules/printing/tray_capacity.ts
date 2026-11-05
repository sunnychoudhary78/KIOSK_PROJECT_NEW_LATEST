import { PrintJobStatus } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import { pagesLeft, usbPagesTotal } from '../devices/printer_tray.js';

const OPEN_JOB_STATUSES: PrintJobStatus[] = [
  PrintJobStatus.created,
  PrintJobStatus.ready,
  PrintJobStatus.printing,
];

export type TrayCapacitySnapshot = {
  pagesLeft: number | null;
  reserved: number;
  /** Null when tray tracking is not configured — capacity checks are skipped. */
  available: number | null;
};

export async function getTrayCapacity(
  db: DbClient,
  deviceId: string,
): Promise<TrayCapacitySnapshot> {
  const device = await db.device.findUnique({
    where: { id: deviceId },
    select: {
      trayPages: true,
      trayBaselinePages: true,
      printerHealth: true,
    },
  });
  if (!device) {
    throw new AppError('not_found', 'Kiosk was not found', 404);
  }

  const left = pagesLeft(
    device.trayPages,
    device.trayBaselinePages,
    usbPagesTotal(device.printerHealth),
  );

  const reservedAgg = await db.printJob.aggregate({
    where: {
      deviceId,
      status: { in: OPEN_JOB_STATUSES },
    },
    _sum: { pagesExpected: true },
  });
  const reserved = Math.max(0, reservedAgg._sum.pagesExpected ?? 0);

  if (left == null) {
    return { pagesLeft: null, reserved, available: null };
  }

  return {
    pagesLeft: left,
    reserved,
    available: Math.max(0, left - reserved),
  };
}

/**
 * Rejects when tray tracking is active and pageCount exceeds remaining capacity
 * (pages left minus open print jobs). No-ops when pagesLeft is unknown.
 */
export async function assertTrayCapacity(
  db: DbClient,
  deviceId: string,
  pageCount: number,
): Promise<void> {
  const needed = Math.max(1, Math.floor(pageCount));
  const { available } = await getTrayCapacity(db, deviceId);
  if (available == null) {
    return;
  }
  if (needed > available) {
    const n = available;
    throw new AppError(
      'insufficient_tray_pages',
      `Only ${n} page${n === 1 ? '' : 's'} left in the printer tray`,
      409,
    );
  }
}
