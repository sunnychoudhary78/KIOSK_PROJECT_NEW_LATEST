import { OtpChallengeStatus, PrintColorMode, PrintJobStatus } from '@prisma/client';
import { describe, expect, it, vi } from 'vitest';
import type { AppConfig } from '../src/config/index.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { SmsClient } from '../src/infrastructure/external/sms.client.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { OtpPrintService } from '../src/modules/otp_print/otp_print.service.js';
import type { PrintingService } from '../src/modules/printing/printing.service.js';
import type { ServicesCatalogService } from '../src/modules/services/services.service.js';
import { hashOtp } from '../src/shared/otp.js';

const challengeId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const deviceId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
const docA = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const docB = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

function makeConfig(): AppConfig {
  return {
    otp: { length: 6, ttlSeconds: 1800 },
    payments: { windowMinutes: 15 },
    razorpay: { keyId: 'rzp_test', keySecret: 'secret' },
  } as AppConfig;
}

function baseDocs() {
  return [
    {
      id: docA,
      challengeId,
      fileName: 'a.pdf',
      storagePath: '/tmp/a.pdf',
      contentType: 'application/pdf',
      pageCount: 2,
      byteSize: 100,
      sortOrder: 0,
      printJobId: null as string | null,
      createdAt: new Date(),
      printJob: null as { id: string; status: PrintJobStatus } | null,
    },
    {
      id: docB,
      challengeId,
      fileName: 'b.pdf',
      storagePath: '/tmp/b.pdf',
      contentType: 'application/pdf',
      pageCount: 3,
      byteSize: 120,
      sortOrder: 1,
      printJobId: null as string | null,
      createdAt: new Date(),
      printJob: null as { id: string; status: PrintJobStatus } | null,
    },
  ];
}

describe('OtpPrintService multi-document jobs', () => {
  it('redeems without creating a session print job', async () => {
    const docs = baseDocs();
    const challenge = {
      id: challengeId,
      userId: 'uuuuuuuu-uuuu-uuuu-uuuu-uuuuuuuuuuuu',
      deviceId,
      codeHash: hashOtp('123456'),
      attemptCount: 0,
      status: OtpChallengeStatus.pending,
      expiresAt: new Date(Date.now() + 60_000),
      documents: docs,
      documentLabel: '2 documents',
      printColorMode: PrintColorMode.bw,
      freePagesGranted: 5,
      printJobId: null,
    };
    const update = vi.fn(async () => challenge);
    const findMany = vi.fn(async () => docs);
    const ledgerUpdateMany = vi.fn(async () => ({ count: 0 }));
    const db = {
      otpChallenge: {
        findFirst: vi.fn(async () => challenge),
        update,
      },
      otpDocument: { findMany },
      device: {
        findUnique: vi.fn(async () => ({ printingPausedReason: null })),
      },
      platformSetting: { findUnique: vi.fn(async () => null) },
      phoneFreePageLedger: { updateMany: ledgerUpdateMany },
    };
    const printing = { createJob: vi.fn() };
    const service = new OtpPrintService(
      db as unknown as DbClient,
      makeConfig(),
      { record: vi.fn() } as unknown as AuditService,
      printing as unknown as PrintingService,
      { assertEnabled: vi.fn(async () => undefined) } as unknown as ServicesCatalogService,
      {} as SmsClient,
    );

    const result = await service.redeem(deviceId, { code: '123456' });

    expect(printing.createJob).not.toHaveBeenCalled();
    expect(result.challengeId).toBe(challengeId);
    expect(result.documents).toHaveLength(2);
    expect(result.documents[0]).toMatchObject({
      id: docA,
      printed: false,
      printJobId: null,
    });
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: OtpChallengeStatus.redeemed,
          deviceId,
        }),
      }),
    );
  });

  it('creates per-document jobs, attaches ledger once, and rejects reprint', async () => {
    const docs = baseDocs();
    const challenge = {
      id: challengeId,
      userId: 'uuuuuuuu-uuuu-uuuu-uuuu-uuuuuuuuuuuu',
      deviceId,
      status: OtpChallengeStatus.redeemed,
      redeemedAt: new Date(),
      documents: docs,
      documentLabel: '2 documents',
      printColorMode: PrintColorMode.bw,
      freePagesGranted: 5,
      printJobId: null,
    };

    const createdJobs: Array<{ id: string; freePagesGranted: number }> = [];
    const printing = {
      createJob: vi.fn(async (input: { title: string; freePagesGranted?: number }) => {
        const job = {
          id: `job-${createdJobs.length + 1}`,
          title: input.title,
          freePagesGranted: input.freePagesGranted ?? 0,
          status: PrintJobStatus.ready,
        };
        createdJobs.push(job);
        return job;
      }),
      get: vi.fn(async (id: string) => ({ id, status: PrintJobStatus.ready })),
    };

    const docUpdate = vi.fn(async ({ where, data }: { where: { id: string }; data: { printJobId: string } }) => {
      const doc = docs.find((d) => d.id === where.id)!;
      doc.printJobId = data.printJobId;
      doc.printJob = { id: data.printJobId, status: PrintJobStatus.ready };
      return doc;
    });
    const ledgerUpdateMany = vi.fn(async () => ({ count: 1 }));

    const db = {
      otpChallenge: {
        findUnique: vi.fn(async () => challenge),
      },
      otpDocument: { update: docUpdate },
      device: {
        findUnique: vi.fn(async () => ({ printingPausedReason: null })),
      },
      platformSetting: { findUnique: vi.fn(async () => null) },
      phoneFreePageLedger: { updateMany: ledgerUpdateMany },
    };

    const service = new OtpPrintService(
      db as unknown as DbClient,
      makeConfig(),
      { record: vi.fn() } as unknown as AuditService,
      printing as unknown as PrintingService,
      { assertEnabled: vi.fn(async () => undefined) } as unknown as ServicesCatalogService,
      {} as SmsClient,
    );

    const first = await service.createDocumentPrintJob(deviceId, challengeId, docA);
    expect(first.printJob.id).toBe('job-1');
    expect(printing.createJob).toHaveBeenLastCalledWith(
      expect.objectContaining({
        title: 'a.pdf',
        pageCount: 2,
        freePagesGranted: 5,
        idempotencyKey: `otp-doc-${docA}`,
      }),
      'device',
      deviceId,
      undefined,
    );
    expect(ledgerUpdateMany).toHaveBeenCalledTimes(1);
    expect(ledgerUpdateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { otpChallengeId: challengeId, printJobId: null },
        data: { printJobId: 'job-1' },
      }),
    );

    const second = await service.createDocumentPrintJob(deviceId, challengeId, docB);
    expect(second.printJob.id).toBe('job-2');
    expect(printing.createJob).toHaveBeenLastCalledWith(
      expect.objectContaining({
        title: 'b.pdf',
        freePagesGranted: 0,
        idempotencyKey: `otp-doc-${docB}`,
      }),
      'device',
      deviceId,
      undefined,
    );
    expect(ledgerUpdateMany).toHaveBeenCalledTimes(1);

    docs[0]!.printJob = { id: 'job-1', status: PrintJobStatus.completed };
    await expect(service.createDocumentPrintJob(deviceId, challengeId, docA)).rejects.toMatchObject({
      code: 'already_printed',
      statusCode: 409,
    });
  });
});
