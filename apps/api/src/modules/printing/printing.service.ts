import {
  PaymentStatus,
  PrintColorMode,
  PrintJobReconcileStatus,
  PrintJobSource,
  PrintJobStatus,
  SupportQueryStatus,
} from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import { PrintQuotaService } from '../print_quota/print_quota.service.js';
import type {
  PrintJobsSummaryQuery,
  UpdatePrintJobStatusInput,
} from './printing.schemas.js';
import { assertPrintingAvailable } from './printing_pause.js';
import { assertTrayCapacity } from './tray_capacity.js';

function parseDayBound(value: string | undefined, endOfDay: boolean): Date | undefined {
  if (!value) return undefined;
  return new Date(`${value}T${endOfDay ? '23:59:59.999' : '00:00:00.000'}Z`);
}

type PaymentSnapshot = {
  status: PaymentStatus;
  amountPaise: number;
  extraPages: number;
  freePages: number;
  paidAt: Date | null;
} | null;

type JobPaymentRelations = {
  payment?: PaymentSnapshot;
  /** Per-document OTP jobs link payment via the parent challenge. */
  otpDocument?: { challenge?: { payment?: PaymentSnapshot } | null } | null;
  /** Per-document Quick Print jobs link payment via the parent session. */
  quickPrintDocument?: { session?: { payment?: PaymentSnapshot } | null } | null;
  /** Legacy single-job rows may still point at challenge/session directly. */
  otpChallenge?: { payment?: PaymentSnapshot } | null;
  quickPrintSession?: { payment?: PaymentSnapshot } | null;
};

function pickPayment(job: JobPaymentRelations): PaymentSnapshot {
  return (
    job.payment ??
    job.otpDocument?.challenge?.payment ??
    job.quickPrintDocument?.session?.payment ??
    job.otpChallenge?.payment ??
    job.quickPrintSession?.payment ??
    null
  );
}

const PAYMENT_SELECT = {
  status: true,
  amountPaise: true,
  extraPages: true,
  freePages: true,
  paidAt: true,
} as const;

function printJobPaymentInclude() {
  return {
    payment: { select: PAYMENT_SELECT },
    otpDocument: {
      select: { challenge: { select: { payment: { select: PAYMENT_SELECT } } } },
    },
    quickPrintDocument: {
      select: { session: { select: { payment: { select: PAYMENT_SELECT } } } },
    },
    otpChallenge: { select: { payment: { select: PAYMENT_SELECT } } },
    quickPrintSession: { select: { payment: { select: PAYMENT_SELECT } } },
  } as const;
}

/** Keep free + paid equal to pageCount so Usage totals never disagree. */
function splitPages(pageCount: number, freeRaw: number, paidRaw: number) {
  const total = Math.max(0, pageCount);
  const freePages = Math.min(Math.max(0, freeRaw), total);
  const paidPages = Math.min(Math.max(0, paidRaw), total - freePages);
  const remainder = total - freePages - paidPages;
  if (remainder <= 0) {
    return { freePages, paidPages };
  }
  // Prefer assigning leftover to the side that already has pages.
  if (paidPages > 0) return { freePages, paidPages: paidPages + remainder };
  return { freePages: freePages + remainder, paidPages };
}

function mapBilling(
  job: { pageCount: number; freePagesGranted?: number | null },
  payment: PaymentSnapshot,
) {
  const freeRaw = job.freePagesGranted ?? payment?.freePages ?? 0;
  const pageCount = job.pageCount;
  if (payment && payment.amountPaise > 0) {
    const billing =
      payment.status === PaymentStatus.PAID
        ? 'paid'
        : payment.status === PaymentStatus.PENDING
          ? 'awaiting_payment'
          : 'unpaid';
    const paidRaw =
      payment.extraPages > 0 ? payment.extraPages : Math.max(0, pageCount - freeRaw);
    const { freePages, paidPages } = splitPages(pageCount, freeRaw, paidRaw);
    return {
      billing,
      amountPaise: payment.amountPaise,
      paymentStatus: payment.status,
      freePages,
      paidPages,
      paidAt: payment.paidAt?.toISOString() ?? null,
    };
  }
  if (freeRaw > 0 && freeRaw < pageCount) {
    const { freePages, paidPages } = splitPages(
      pageCount,
      freeRaw,
      Math.max(0, pageCount - freeRaw),
    );
    return {
      billing: 'mixed' as const,
      amountPaise: 0,
      paymentStatus: payment?.status ?? null,
      freePages,
      paidPages,
      paidAt: payment?.paidAt?.toISOString() ?? null,
    };
  }
  const { freePages, paidPages } = splitPages(
    pageCount,
    freeRaw > 0 ? freeRaw : pageCount,
    0,
  );
  return {
    billing: 'free' as const,
    amountPaise: 0,
    paymentStatus: payment?.status ?? null,
    freePages,
    paidPages,
    paidAt: null,
  };
}

function mapJob(
  job: {
    id: string;
    status: PrintJobStatus;
    source: PrintJobSource;
    title: string;
    pageCount: number;
    copies?: number;
    pagesExpected: number;
    pagesReported: number | null;
    spoolerJobId: string | null;
    pageCounterBefore: number | null;
    pageCounterAfter: number | null;
    reconcileStatus: PrintJobReconcileStatus;
    needsAdminReview: boolean;
    reconcileDetail: string | null;
    reconciledAt: Date | null;
    freePagesGranted?: number | null;
    printColorMode?: PrintColorMode | null;
    errorMessage?: string | null;
    deviceId: string | null;
    device?: { name: string; site?: { name: string } | null } | null;
    payloadUrl: string | null;
    payloadPath?: string | null;
    createdAt: Date;
    updatedAt: Date;
  } & JobPaymentRelations,
) {
  const payment = pickPayment(job);
  const billing = mapBilling(job, payment);
  return {
    id: job.id,
    status: job.status,
    source: job.source,
    title: job.title,
    pageCount: job.pageCount,
    copies: job.copies ?? 1,
    pagesExpected: job.pagesExpected,
    pagesReported: job.pagesReported,
    spoolerJobId: job.spoolerJobId,
    pageCounterBefore: job.pageCounterBefore,
    pageCounterAfter: job.pageCounterAfter,
    reconcileStatus: job.reconcileStatus,
    needsAdminReview: job.needsAdminReview,
    reconcileDetail: job.reconcileDetail,
    reconciledAt: job.reconciledAt?.toISOString() ?? null,
    errorMessage: job.errorMessage ?? null,
    freePagesGranted: job.freePagesGranted ?? 0,
    printColorMode: job.printColorMode === PrintColorMode.color ? 'color' : 'bw',
    deviceId: job.deviceId,
    kioskName: job.device?.name ?? null,
    siteName: job.device?.site?.name ?? null,
    payloadUrl: job.payloadUrl,
    createdAt: job.createdAt.toISOString(),
    updatedAt: job.updatedAt.toISOString(),
    ...billing,
  };
}

export type CreatePrintJobInput = {
  source: PrintJobSource;
  title: string;
  pageCount?: number;
  copies?: number;
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
    const copies = input.copies ?? 1;
    const pagesExpected = input.pagesExpected ?? pageCount * copies;

    if (input.deviceId) {
      await assertPrintingAvailable(this.db, input.deviceId);
      await assertTrayCapacity(this.db, input.deviceId, pagesExpected);
    }

    const job = await this.db.printJob.create({
      data: {
        source: input.source,
        title: input.title,
        pageCount,
        copies,
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
    const items = await this.db.printJob.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        device: { select: { name: true, site: { select: { name: true } } } },
        ...printJobPaymentInclude(),
      },
    });
    return { items: items.map(mapJob) };
  }

  async summarize(query: PrintJobsSummaryQuery) {
    const from = parseDayBound(query.from, false);
    const to = parseDayBound(query.to, true);
    const items = await this.db.printJob.findMany({
      where: {
        ...(query.deviceId ? { deviceId: query.deviceId } : {}),
        ...(from || to
          ? {
              createdAt: {
                ...(from ? { gte: from } : {}),
                ...(to ? { lte: to } : {}),
              },
            }
          : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: 5000,
      include: {
        device: { select: { name: true, site: { select: { name: true } } } },
        ...printJobPaymentInclude(),
      },
    });

    const mapped = items.map(mapJob);
    let pages = 0;
    let freePages = 0;
    let paidPages = 0;
    let freeJobs = 0;
    let paidJobs = 0;
    let mixedJobs = 0;
    let otherJobs = 0;

    for (const job of mapped) {
      const split = splitPages(job.pageCount, job.freePages, job.paidPages);
      pages += job.pageCount;
      freePages += split.freePages;
      paidPages += split.paidPages;
      if (job.billing === 'free') freeJobs += 1;
      else if (job.billing === 'paid') paidJobs += 1;
      else if (job.billing === 'mixed') mixedJobs += 1;
      else otherJobs += 1;
    }

    return {
      jobs: mapped.length,
      pages,
      freePages,
      paidPages,
      freeJobs,
      paidJobs,
      mixedJobs,
      otherJobs,
    };
  }

  async get(jobId: string) {
    const job = await this.db.printJob.findUnique({
      where: { id: jobId },
      include: {
        device: { select: { name: true, site: { select: { name: true } } } },
        ...printJobPaymentInclude(),
      },
    });
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
    const job = await this.db.printJob.findUnique({
      where: { id: jobId },
      include: { payment: true },
    });
    if (!job) {
      throw new AppError('not_found', 'Print job not found', 404);
    }
    if (job.deviceId && job.deviceId !== deviceId) {
      throw new AppError('forbidden', 'Print job belongs to another device', 403);
    }

    const status = input.status as PrintJobStatus;
    if (status === PrintJobStatus.printing) {
      const payment = job.payment;
      if (payment && payment.amountPaise > 0 && payment.status !== PaymentStatus.PAID) {
        if (payment.status === PaymentStatus.PENDING && payment.expiresAt.getTime() < Date.now()) {
          await this.db.payment.update({
            where: { id: payment.id },
            data: { status: PaymentStatus.EXPIRED },
          });
          throw new AppError('payment_expired', 'Payment window has expired', 400);
        }
        throw new AppError('payment_required', 'Payment is not complete yet', 402);
      }
    }

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
    } else if (
      status === PrintJobStatus.failed &&
      (pagesReported == null || pagesReported === 0) &&
      input.holdForRetry !== true
    ) {
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
        title: job.title,
        source: job.source,
        printColorMode: job.printColorMode,
        ...(input.errorMessage ? { errorMessage: input.errorMessage } : {}),
        reconcileStatus,
        pagesReported: pagesReported ?? undefined,
        needsAdminReview,
      },
    });

    return mapJob(updated);
  }

  /**
   * Admin/operator: close an open job as failed so it stops reserving tray pages.
   */
  async adminCloseJob(
    jobId: string,
    adminId: string,
    correlationId?: string,
  ) {
    const job = await this.db.printJob.findUnique({ where: { id: jobId } });
    if (!job) {
      throw new AppError('not_found', 'Print job not found', 404);
    }
    const open: PrintJobStatus[] = [
      PrintJobStatus.created,
      PrintJobStatus.ready,
      PrintJobStatus.printing,
    ];
    if (!open.includes(job.status)) {
      throw new AppError(
        'invalid_state',
        'Only open print jobs (created, ready, printing) can be cleared',
        409,
      );
    }

    const updated = await this.db.printJob.update({
      where: { id: jobId },
      data: {
        status: PrintJobStatus.failed,
        needsAdminReview: true,
        reconcileDetail: 'admin_clear_stuck',
        reconciledAt: job.reconciledAt ?? new Date(),
      },
    });

    await this.quota.releaseForPrintJob(jobId).catch(() => undefined);

    await this.audit.record({
      action: 'print_job.admin_close',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'print_job',
      resourceId: jobId,
      correlationId,
      metadata: {
        title: job.title,
        source: job.source,
        previousStatus: job.status,
        deviceId: job.deviceId,
        reason: 'admin_clear_stuck',
      },
    });

    return mapJob(updated);
  }

  /** Admin/operator: fail all open jobs for one kiosk (lab / stuck-tray reset). */
  async adminCloseOpenForDevice(
    deviceId: string,
    adminId: string,
    correlationId?: string,
  ) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { id: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const open = await this.db.printJob.findMany({
      where: {
        deviceId,
        status: {
          in: [PrintJobStatus.created, PrintJobStatus.ready, PrintJobStatus.printing],
        },
      },
      select: { id: true },
    });

    const closed = [];
    for (const row of open) {
      closed.push(await this.adminCloseJob(row.id, adminId, correlationId));
    }
    return { closedCount: closed.length, items: closed };
  }

  async openJobSupportNote(
    jobId: string,
    deviceId: string,
    message: string,
    correlationId?: string,
  ) {
    const job = await this.db.printJob.findUnique({ where: { id: jobId } });
    if (!job || job.deviceId !== deviceId) {
      throw new AppError('not_found', 'Print job not found', 404);
    }
    const existing = await this.db.supportQuery.findUnique({ where: { printJobId: jobId } });
    if (existing) {
      return { id: existing.id, status: existing.status, message: existing.message };
    }
    const created = await this.db.supportQuery.create({
      data: {
        printJobId: jobId,
        message,
        phone: '',
        amountPaise: 0,
        failureReason: job.errorMessage,
        status: SupportQueryStatus.open,
      },
    });
    await this.audit.record({
      action: 'support_query.opened',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'support_query',
      resourceId: created.id,
      correlationId,
      metadata: { printJobId: jobId },
    });
    return { id: created.id, status: created.status, message: created.message };
  }
}
