import {
  PrintColorMode,
  PrintJobReconcileStatus,
  PrintJobSource,
  PrintJobStatus,
} from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import { PrintQuotaService } from '../print_quota/print_quota.service.js';
import type { UpdatePrintJobStatusInput } from './printing.schemas.js';

function mapJob(job: {
  id: string;
  status: PrintJobStatus;
  source: PrintJobSource;
  title: string;
  pageCount: number;
  pagesExpected: number;
  pagesReported: number | null;
  spoolerJobId: string | null;
  pageCounterBefore: number | null;
  pageCounterAfter: number | null;
  reconcileStatus: PrintJobReconcileStatus;
  needsAdminReview: boolean;
  reconcileDetail: string | null;
  reconciledAt: Date | null;
  printColorMode?: PrintColorMode | null;
  deviceId: string | null;
  payloadUrl: string | null;
  payloadPath?: string | null;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: job.id,
    status: job.status,
    source: job.source,
    title: job.title,
    pageCount: job.pageCount,
    pagesExpected: job.pagesExpected,
    pagesReported: job.pagesReported,
    spoolerJobId: job.spoolerJobId,
    pageCounterBefore: job.pageCounterBefore,
    pageCounterAfter: job.pageCounterAfter,
    reconcileStatus: job.reconcileStatus,
    needsAdminReview: job.needsAdminReview,
    reconcileDetail: job.reconcileDetail,
    reconciledAt: job.reconciledAt?.toISOString() ?? null,
    printColorMode: job.printColorMode === PrintColorMode.color ? 'color' : 'bw',
    deviceId: job.deviceId,
    payloadUrl: job.payloadUrl,
    createdAt: job.createdAt.toISOString(),
    updatedAt: job.updatedAt.toISOString(),
  };
}

export type CreatePrintJobInput = {
  source: PrintJobSource;
  title: string;
  pageCount?: number;
  pagesExpected?: number;
  freePagesGranted?: number;
  printColorMode?: PrintColorMode;
  deviceId?: string;
  payloadUrl?: string;
  payloadPath?: string;
  idempotencyKey?: string;
  digiLockerSessionId?: string;
};

const HOLD_RECONCILE = new Set<PrintJobReconcileStatus>([
  PrintJobReconcileStatus.partial,
  PrintJobReconcileStatus.reconciliation_required,
  PrintJobReconcileStatus.unknown,
]);

function toReconcileStatus(
  value: string | undefined,
): PrintJobReconcileStatus | undefined {
  if (!value) return undefined;
  return value as PrintJobReconcileStatus;
}

export class PrintingService {
  private readonly quota: PrintQuotaService;

  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {
    this.quota = new PrintQuotaService(db, audit);
  }

  async createJob(input: CreatePrintJobInput, principalType: 'citizen' | 'device' | 'system', principalId?: string, correlationId?: string) {
    if (input.idempotencyKey) {
      const existing = await this.db.printJob.findUnique({
        where: { idempotencyKey: input.idempotencyKey },
      });
      if (existing) {
        return mapJob(existing);
      }
    }

    const pageCount = input.pageCount ?? 1;
    const pagesExpected = input.pagesExpected ?? pageCount;

    const job = await this.db.printJob.create({
      data: {
        source: input.source,
        title: input.title,
        pageCount,
        pagesExpected,
        freePagesGranted: input.freePagesGranted ?? 0,
        printColorMode: input.printColorMode ?? PrintColorMode.bw,
        deviceId: input.deviceId,
        payloadUrl: input.payloadUrl,
        payloadPath: input.payloadPath,
        idempotencyKey: input.idempotencyKey,
        digiLockerSessionId: input.digiLockerSessionId,
        status: PrintJobStatus.ready,
        reconcileStatus: PrintJobReconcileStatus.pending,
      },
    });

    await this.audit.record({
      action: 'print_job.created',
      principalType,
      principalId,
      resourceType: 'print_job',
      resourceId: job.id,
      correlationId,
      metadata: { source: job.source, title: job.title, printColorMode: job.printColorMode },
    });

    return mapJob(job);
  }

  async attachPayload(jobId: string, input: { payloadPath: string; payloadUrl: string }) {
    const job = await this.db.printJob.update({
      where: { id: jobId },
      data: {
        payloadPath: input.payloadPath,
        payloadUrl: input.payloadUrl,
      },
    });
    return mapJob(job);
  }

  async getContentForDevice(jobId: string, deviceId: string) {
    const job = await this.db.printJob.findUnique({ where: { id: jobId } });
    if (!job) {
      throw new AppError('not_found', 'Print job not found', 404);
    }
    if (job.deviceId && job.deviceId !== deviceId) {
      throw new AppError('forbidden', 'Print job belongs to another device', 403);
    }
    if (!job.payloadPath) {
      throw new AppError('payload_missing', 'Print job has no downloadable content', 404);
    }
    return {
      payloadPath: job.payloadPath,
      title: job.title,
    };
  }

  async list() {
    const items = await this.db.printJob.findMany({ orderBy: { createdAt: 'desc' }, take: 100 });
    return { items: items.map(mapJob) };
  }

  async get(jobId: string) {
    const job = await this.db.printJob.findUnique({ where: { id: jobId } });
    if (!job) {
      throw new AppError('not_found', 'Print job not found', 404);
    }
    return mapJob(job);
  }

  async updateStatus(
    jobId: string,
    input: UpdatePrintJobStatusInput,
    deviceId: string,
    correlationId?: string,
  ) {
    const job = await this.db.printJob.findUnique({ where: { id: jobId } });
    if (!job) {
      throw new AppError('not_found', 'Print job not found', 404);
    }
    if (job.deviceId && job.deviceId !== deviceId) {
      throw new AppError('forbidden', 'Print job belongs to another device', 403);
    }

    const status = input.status as PrintJobStatus;
    const reconcileStatus =
      toReconcileStatus(input.reconcileStatus) ?? job.reconcileStatus;
    const pagesExpected = job.pagesExpected > 0 ? job.pagesExpected : job.pageCount;
    const pagesReported =
      input.pagesReported !== undefined ? input.pagesReported : job.pagesReported;

    // Idempotent: already completed — return current row without flipping ledger again.
    if (job.status === PrintJobStatus.completed) {
      return mapJob(job);
    }

    if (status === PrintJobStatus.completed) {
      if (reconcileStatus !== PrintJobReconcileStatus.verified) {
        throw new AppError(
          'invalid_reconcile',
          'completed requires reconcileStatus=verified',
          400,
        );
      }
      if (pagesReported == null || pagesReported < pagesExpected) {
        throw new AppError(
          'invalid_reconcile',
          'completed requires pagesReported >= pagesExpected',
          400,
        );
      }
    }

    if (
      reconcileStatus === PrintJobReconcileStatus.verified &&
      status !== PrintJobStatus.completed
    ) {
      throw new AppError(
        'invalid_reconcile',
        'reconcileStatus=verified requires status=completed',
        400,
      );
    }

    const holdReconcile = HOLD_RECONCILE.has(reconcileStatus);
    const failedWithPages =
      status === PrintJobStatus.failed && pagesReported != null && pagesReported > 0;
    const needsAdminReview =
      input.needsAdminReview === true ||
      holdReconcile ||
      failedWithPages ||
      job.needsAdminReview;

    const updated = await this.db.printJob.update({
      where: { id: jobId },
      data: {
        status,
        deviceId: job.deviceId ?? deviceId,
        errorMessage: input.errorMessage,
        pagesReported: input.pagesReported !== undefined ? input.pagesReported : undefined,
        spoolerJobId: input.spoolerJobId !== undefined ? input.spoolerJobId : undefined,
        pageCounterBefore:
          input.pageCounterBefore !== undefined ? input.pageCounterBefore : undefined,
        pageCounterAfter:
          input.pageCounterAfter !== undefined ? input.pageCounterAfter : undefined,
        reconcileStatus:
          input.reconcileStatus !== undefined ? reconcileStatus : undefined,
        reconcileDetail:
          input.reconcileDetail !== undefined ? input.reconcileDetail : undefined,
        needsAdminReview,
        ...(input.reconcileStatus !== undefined
          ? {
              reconciledAt:
                reconcileStatus === PrintJobReconcileStatus.pending
                  ? null
                  : (job.reconciledAt ?? new Date()),
            }
          : {}),
      },
    });

    if (status === PrintJobStatus.completed && reconcileStatus === PrintJobReconcileStatus.verified) {
      await this.quota.consumeForPrintJob(jobId).catch(() => undefined);
    } else if (status === PrintJobStatus.failed && (pagesReported == null || pagesReported === 0)) {
      await this.quota.releaseForPrintJob(jobId).catch(() => undefined);
    }
    // partial / reconciliation_required / unknown / failed-with-pages: leave ledger reserved

    await this.audit.record({
      action: `print_job.${status}`,
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'print_job',
      resourceId: jobId,
      correlationId,
      metadata: {
        ...(input.errorMessage ? { errorMessage: input.errorMessage } : {}),
        reconcileStatus,
        pagesReported: pagesReported ?? undefined,
        needsAdminReview,
      },
    });

    return mapJob(updated);
  }
}
