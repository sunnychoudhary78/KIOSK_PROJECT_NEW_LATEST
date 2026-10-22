import { describe, expect, it, vi } from 'vitest';
import {
  FreePageLedgerStatus,
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
    reconcileStatus: PrintJobReconcileStatus.pending,
    needsAdminReview: false,
    reconcileDetail: null as string | null,
    reconciledAt: null as Date | null,
    freePagesGranted: 2,
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

function makeService(job: ReturnType<typeof baseJob>) {
  const ledgerUpdateMany = vi.fn(async () => ({ count: 1 }));
  let current = { ...job };
  const db = {
    printJob: {
      findUnique: vi.fn(async () => current),
      update: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
        current = { ...current, ...data, updatedAt: new Date() };
        return current;
      }),
      create: vi.fn(),
      findMany: vi.fn(),
    },
    phoneFreePageLedger: {
      updateMany: ledgerUpdateMany,
      findMany: vi.fn(async () => []),
      findUnique: vi.fn(),
      create: vi.fn(),
    },
    platformSetting: {
      findUnique: vi.fn(async () => null),
    },
  };
  const audit = { record: vi.fn(async () => undefined) };
  const service = new PrintingService(
    db as unknown as DbClient,
    audit as unknown as AuditService,
  );
  return { service, db, audit, ledgerUpdateMany, getCurrent: () => current };
}

describe('PrintingService.updateStatus reconciliation', () => {
  it('rejects completed without reconcileStatus=verified', async () => {
    const { service } = makeService(baseJob());
    await expect(
      service.updateStatus(jobId, { status: 'completed' }, deviceId),
    ).rejects.toMatchObject({
      code: 'invalid_reconcile',
      statusCode: 400,
    } satisfies Partial<AppError>);
  });

  it('rejects completed when pagesReported < pagesExpected', async () => {
    const { service } = makeService(baseJob());
    await expect(
      service.updateStatus(
        jobId,
        {
          status: 'completed',
          reconcileStatus: 'verified',
          pagesReported: 2,
        },
        deviceId,
      ),
    ).rejects.toMatchObject({ code: 'invalid_reconcile' });
  });

  it('rejects verified with non-completed status', async () => {
    const { service } = makeService(baseJob());
    await expect(
      service.updateStatus(
        jobId,
        {
          status: 'printing',
          reconcileStatus: 'verified',
          pagesReported: 3,
        },
        deviceId,
      ),
    ).rejects.toMatchObject({ code: 'invalid_reconcile' });
  });

  it('consumes free-page ledger on completed + verified', async () => {
    const { service, ledgerUpdateMany, getCurrent } = makeService(baseJob());
    const result = await service.updateStatus(
      jobId,
      {
        status: 'completed',
        reconcileStatus: 'verified',
        pagesReported: 3,
        pageCounterBefore: 100,
        pageCounterAfter: 103,
        spoolerJobId: '42',
      },
      deviceId,
    );
    expect(result.status).toBe('completed');
    expect(result.reconcileStatus).toBe('verified');
    expect(result.pagesReported).toBe(3);
    expect(result.needsAdminReview).toBe(false);
    expect(ledgerUpdateMany).toHaveBeenCalledWith({
      where: { printJobId: jobId, status: FreePageLedgerStatus.reserved },
      data: { status: FreePageLedgerStatus.consumed },
    });
    expect(getCurrent().reconciledAt).toBeInstanceOf(Date);
  });

  it('is idempotent when job is already completed', async () => {
    const { service, ledgerUpdateMany, db } = makeService(
      baseJob({
        status: PrintJobStatus.completed,
        reconcileStatus: PrintJobReconcileStatus.verified,
        pagesReported: 3,
      }),
    );
    const result = await service.updateStatus(
      jobId,
      {
        status: 'completed',
        reconcileStatus: 'verified',
        pagesReported: 3,
      },
      deviceId,
    );
    expect(result.status).toBe('completed');
    expect(db.printJob.update).not.toHaveBeenCalled();
    expect(ledgerUpdateMany).not.toHaveBeenCalled();
  });

  it('holds reservation and flags review on reconciliation_required', async () => {
    const { service, ledgerUpdateMany, getCurrent } = makeService(baseJob());
    const result = await service.updateStatus(
      jobId,
      {
        status: 'printing',
        reconcileStatus: 'reconciliation_required',
        reconcileDetail: 'timeout: no SNMP page delta within 180s',
        pagesReported: 0,
      },
      deviceId,
    );
    expect(result.status).toBe('printing');
    expect(result.reconcileStatus).toBe('reconciliation_required');
    expect(result.needsAdminReview).toBe(true);
    expect(result.reconcileDetail).toContain('timeout');
    expect(ledgerUpdateMany).not.toHaveBeenCalled();
    expect(getCurrent().needsAdminReview).toBe(true);
  });

  it('holds reservation and flags review on unknown', async () => {
    const { service, ledgerUpdateMany } = makeService(baseJob());
    const result = await service.updateStatus(
      jobId,
      {
        status: 'printing',
        reconcileStatus: 'unknown',
        reconcileDetail: 'snmp unreachable',
      },
      deviceId,
    );
    expect(result.reconcileStatus).toBe('unknown');
    expect(result.needsAdminReview).toBe(true);
    expect(ledgerUpdateMany).not.toHaveBeenCalled();
  });

  it('releases ledger on failed with zero pages printed', async () => {
    const { service, ledgerUpdateMany } = makeService(baseJob());
    await service.updateStatus(
      jobId,
      {
        status: 'failed',
        pagesReported: 0,
        errorMessage: 'paper jam before first page',
      },
      deviceId,
    );
    expect(ledgerUpdateMany).toHaveBeenCalledWith({
      where: { printJobId: jobId, status: FreePageLedgerStatus.reserved },
      data: { status: FreePageLedgerStatus.released },
    });
  });

  it('holds reservation and flags review on failed with partial pages', async () => {
    const { service, ledgerUpdateMany } = makeService(baseJob());
    const result = await service.updateStatus(
      jobId,
      {
        status: 'failed',
        pagesReported: 1,
        reconcileStatus: 'partial',
        errorMessage: 'jam after page 1',
      },
      deviceId,
    );
    expect(result.status).toBe('failed');
    expect(result.needsAdminReview).toBe(true);
    expect(ledgerUpdateMany).not.toHaveBeenCalled();
  });

  it('createJob sets pagesExpected from pageCount', async () => {
    const created = baseJob({
      status: PrintJobStatus.ready,
      pageCount: 5,
      pagesExpected: 5,
    });
    const db = {
      printJob: {
        findUnique: vi.fn(async () => null),
        create: vi.fn(async ({ data }: { data: Record<string, unknown> }) => ({
          ...created,
          ...data,
          id: jobId,
          createdAt: new Date(),
          updatedAt: new Date(),
        })),
      },
      phoneFreePageLedger: { updateMany: vi.fn() },
      platformSetting: { findUnique: vi.fn(async () => null) },
    };
    const service = new PrintingService(
      db as unknown as DbClient,
      { record: vi.fn(async () => undefined) } as unknown as AuditService,
    );
    const result = await service.createJob(
      {
        source: PrintJobSource.quick_print,
        title: 'q.pdf',
        pageCount: 5,
        deviceId,
      },
      'device',
      deviceId,
    );
    expect(db.printJob.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        pageCount: 5,
        pagesExpected: 5,
        reconcileStatus: PrintJobReconcileStatus.pending,
      }),
    });
    expect(result.pagesExpected).toBe(5);
    expect(result.reconcileStatus).toBe('pending');
  });
});
