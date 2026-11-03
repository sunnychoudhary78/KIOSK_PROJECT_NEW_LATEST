import { PrintJobSource } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { AuditService } from '../audit/audit.service.js';
import { createPrintJobWithPdf } from '../printing/create_print_job_with_pdf.js';
import { assertPrintingAvailable } from '../printing/printing_pause.js';
import { PrintingService } from '../printing/printing.service.js';
import { buildHealthReportPdf } from './well_being_report_pdf.js';
import type { WellBeingPrintBody } from './well_being.schemas.js';

export class WellBeingService {
  private readonly printing: PrintingService;

  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {
    this.printing = new PrintingService(db, audit);
  }

  async printReport(deviceId: string, input: WellBeingPrintBody, correlationId?: string) {
    await assertPrintingAvailable(this.db, deviceId);
    const bytes = await buildHealthReportPdf(input);
    const title =
      input.mode === 'oxi' ? 'Health Report — Pulse oximetry' : 'Health Report — Temperature';
    const job = await createPrintJobWithPdf(
      this.printing,
      {
        source: PrintJobSource.well_being_print,
        title,
        deviceId,
        bytes,
        folder: 'well_being',
        idempotencyKey:
          input.idempotencyKey ??
          `wb-${input.mode}-${deviceId}-${input.measuredAt ?? Date.now()}`.slice(0, 100),
      },
      'device',
      correlationId,
    );

    await this.audit.record({
      action: 'well_being.print_requested',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'print_job',
      resourceId: job.id,
      correlationId,
      metadata: { mode: input.mode },
    });

    return job;
  }
}
