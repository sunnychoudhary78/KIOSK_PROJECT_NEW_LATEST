import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { PrintColorMode, PrintJobSource } from '@prisma/client';
import { countPdfPages } from './report_pdf.js';
import type { PrintingService } from './printing.service.js';

export type CreatePrintJobWithPdfInput = {
  source: PrintJobSource;
  title: string;
  deviceId: string;
  bytes: Buffer;
  idempotencyKey?: string;
  printColorMode?: PrintColorMode;
  freePagesGranted?: number;
  folder?: string;
};

export async function createPrintJobWithPdf(
  printing: PrintingService,
  input: CreatePrintJobWithPdfInput,
  principalType: 'citizen' | 'device' | 'system' = 'device',
  correlationId?: string,
) {
  const pageCount = await countPdfPages(input.bytes);
  const folder = input.folder ?? input.source;
  const job = await printing.createJob(
    {
      source: input.source,
      title: input.title,
      pageCount,
      pagesExpected: pageCount,
      deviceId: input.deviceId,
      printColorMode: input.printColorMode ?? PrintColorMode.color,
      freePagesGranted: input.freePagesGranted ?? 0,
      payloadUrl: `/v1/print-jobs/pending/content`,
      idempotencyKey: input.idempotencyKey?.slice(0, 100),
    },
    principalType,
    input.deviceId,
    correlationId,
  );

  const payloadDir = join(process.cwd(), 'tmp', folder);
  await mkdir(payloadDir, { recursive: true });
  const payloadPath = join(payloadDir, `${job.id}.pdf`);
  await writeFile(payloadPath, input.bytes);

  return printing.attachPayload(job.id, {
    payloadPath,
    payloadUrl: `/v1/print-jobs/${job.id}/content`,
  });
}
