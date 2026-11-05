import { describe, expect, it, vi } from 'vitest';
import {
  PrintJobReconcileStatus,
  PrintJobSource,
  PrintJobStatus,
  PrintColorMode,
} from '@prisma/client';
import { PrintingService } from '../src/modules/printing/printing.service.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { AppError } from '../src/shared/errors.js';

const jobId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const deviceId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const adminId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

function baseJob(overrides: Record<string, unknown> = {}) {
  return {
    id: jobId,
    deviceId,
    source: PrintJobSource.otp_print,
    status: PrintJobStatus.printing,
    title: 'doc.pdf',
    pageCount: 3,
    pagesExpected: 3,
    pagesReported: null as number | null,
    spoolerJobId: null as string | null,
    pageCounterBefore: null as number | null,
    pageCounterAfter: null as number | null,
    reconcileStatus: PrintJobReconcileStatus.unknown,
    needsAdminReview: true,
    reconcileDetail: 'usb_baseline_unavailable' as string | null,
    reconciledAt: null as Date | null,
    freePagesGranted: 0,
    printColorMode: PrintColorMode.bw,
    payloadUrl: null,
    payloadPath: null,
    errorMessage: null,
    idempotencyKey: null,
    digiLockerSessionId: null,
    createdAt: new Date('2026-10-22T10:00:00.000Z'),
    updatedAt: new Date('2026-10-22T10:00:00.000Z'),
    ...overrides,
  };
}

describe('PrintingService.adminCloseJob', () => {
  it('fails an open printing job', async () => {
    let current = baseJob();
    const ledgerUpdateMany = vi.fn(async () => ({ count: 0 }));
    const db = {
      printJob: {
        findUnique: vi.fn(async () => current),
        update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
          current = { ...current, ...data, updatedAt: new Date() };
          return current;
        }),
        findMany: vi.fn(),
      },
      device: { findUnique: vi.fn() },
      phoneFreePageLedger: {
        updateMany: ledgerUpdateMany,
        findMany: vi.fn(async () => []),
      },
      platformSetting: { findUnique: vi.fn(async () => null) },
    };
    const audit = { record: vi.fn(async () => undefined) };
    const service = new PrintingService(
      db as unknown as DbClient,
      audit as unknown as AuditService,
    );

    const result = await service.adminCloseJob(jobId, adminId);
    expect(result.status).toBe(PrintJobStatus.failed);
    expect(result.reconcileDetail).toBe('admin_clear_stuck');
    expect(result.needsAdminReview).toBe(true);
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'print_job.admin_close', principalId: adminId }),
    );
  });

  it('rejects already completed jobs', async () => {
    const db = {
      printJob: {
        findUnique: vi.fn(async () => baseJob({ status: PrintJobStatus.completed })),
        update: vi.fn(),
        findMany: vi.fn(),
      },
      device: { findUnique: vi.fn() },
      phoneFreePageLedger: { updateMany: vi.fn(), findMany: vi.fn() },
      platformSetting: { findUnique: vi.fn(async () => null) },
    };
    const service = new PrintingService(
      db as unknown as DbClient,
      { record: vi.fn() } as unknown as AuditService,
    );
    await expect(service.adminCloseJob(jobId, adminId)).rejects.toMatchObject({
      code: 'invalid_state',
      statusCode: 409,
    } satisfies Partial<AppError>);
  });

  it('closes all open jobs for a device', async () => {
    const openIds = ['job-1', 'job-2'];
    const jobs = new Map(
      openIds.map((id) => [id, baseJob({ id, status: PrintJobStatus.ready })]),
    );
    const db = {
      printJob: {
        findUnique: vi.fn(async ({ where }: { where: { id: string } }) => jobs.get(where.id) ?? null),
        update: vi.fn(async ({ where, data }: { where: { id: string }; data: Record<string, unknown> }) => {
          const cur = jobs.get(where.id)!;
          const next = { ...cur, ...data };
          jobs.set(where.id, next);
          return next;
        }),
        findMany: vi.fn(async () => openIds.map((id) => ({ id }))),
      },
      device: { findUnique: vi.fn(async () => ({ id: deviceId })) },
      phoneFreePageLedger: {
        updateMany: vi.fn(async () => ({ count: 0 })),
        findMany: vi.fn(async () => []),
      },
      platformSetting: { findUnique: vi.fn(async () => null) },
    };
    const service = new PrintingService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );

    const result = await service.adminCloseOpenForDevice(deviceId, adminId);
    expect(result.closedCount).toBe(2);
    expect(result.items.every((j) => j.status === PrintJobStatus.failed)).toBe(true);
  });
});
