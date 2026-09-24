import { PrintColorMode, PrintJobSource, PrintJobStatus } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import type { UpdatePrintJobStatusInput } from './printing.schemas.js';

function mapJob(job: {
  id: string;
  status: PrintJobStatus;
  source: PrintJobSource;
  title: string;
  pageCount: number;
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
  printColorMode?: PrintColorMode;
  deviceId?: string;
  payloadUrl?: string;
  payloadPath?: string;
  idempotencyKey?: string;
  digiLockerSessionId?: string;
};

export class PrintingService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {}

  async createJob(input: CreatePrintJobInput, principalType: 'citizen' | 'device' | 'system', principalId?: string, correlationId?: string) {
    if (input.idempotencyKey) {
      const existing = await this.db.printJob.findUnique({
        where: { idempotencyKey: input.idempotencyKey },
      });
      if (existing) {
        return mapJob(existing);
      }
    }

    const job = await this.db.printJob.create({
      data: {
        source: input.source,
        title: input.title,
        pageCount: input.pageCount ?? 1,
        printColorMode: input.printColorMode ?? PrintColorMode.bw,
        deviceId: input.deviceId,
        payloadUrl: input.payloadUrl,
        payloadPath: input.payloadPath,
        idempotencyKey: input.idempotencyKey,
        digiLockerSessionId: input.digiLockerSessionId,
        status: PrintJobStatus.ready,
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
    const updated = await this.db.printJob.update({
      where: { id: jobId },
      data: {
        status,
        deviceId: job.deviceId ?? deviceId,
        errorMessage: input.errorMessage,
      },
    });

    await this.audit.record({
      action: `print_job.${status}`,
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'print_job',
      resourceId: jobId,
      correlationId,
      metadata: input.errorMessage ? { errorMessage: input.errorMessage } : undefined,
    });

    return mapJob(updated);
  }
}
