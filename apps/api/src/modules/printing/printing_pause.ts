import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';

export const PRINTING_PAUSED_PAPER_OUT = 'paper_out';

export function printerReportsPaperOut(printer: unknown): boolean {
  if (!printer || typeof printer !== 'object') return false;
  const row = printer as {
    state?: unknown;
    noPaper?: unknown;
    snmpReachable?: unknown;
  };
  if (row.snmpReachable === false) return false;
  return row.state === 'paper_out' || row.noPaper === true;
}

export async function assertPrintingAvailable(db: DbClient, deviceId: string) {
  const device = await db.device.findUnique({
    where: { id: deviceId },
    select: { printingPausedReason: true },
  });
  if (!device) {
    throw new AppError('not_found', 'Kiosk was not found', 404);
  }
  if (device.printingPausedReason) {
    throw new AppError('printing_paused', 'Printing is paused because the printer is out of paper', 403);
  }
}
