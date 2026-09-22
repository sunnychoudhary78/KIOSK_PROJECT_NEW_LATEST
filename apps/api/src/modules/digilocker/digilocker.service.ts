import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { DigiLockerSessionStatus, PrintJobSource } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import {
  startDigiLockerAuthorization,
} from '../../infrastructure/external/digilocker.client.js';
import type { DigiLockerClient } from '../../infrastructure/external/digilocker.types.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import { PrintingService } from '../printing/printing.service.js';
import { ServicesCatalogService } from '../services/services.service.js';
import type { PrintDigiLockerInput, StartDigiLockerSessionInput } from './digilocker.schemas.js';

const SESSION_TTL_SECONDS = 600;

function mapSession(session: {
  id: string;
  status: DigiLockerSessionStatus;
  authorizationUrl: string;
  expiresAt: Date;
  authorizedAt: Date | null;
}) {
  return {
    id: session.id,
    status: session.status,
    authorizationUrl: session.authorizationUrl,
    expiresAt: session.expiresAt.toISOString(),
    authorizedAt: session.authorizedAt?.toISOString() ?? null,
  };
}

export class DigiLockerService {
  constructor(
    private readonly db: DbClient,
    private readonly digiLocker: DigiLockerClient,
    private readonly audit: AuditService,
    private readonly printing: PrintingService,
    private readonly services: ServicesCatalogService,
  ) {}

  async startSession(deviceId: string, _input: StartDigiLockerSessionInput, correlationId?: string) {
    await this.services.assertEnabled(deviceId, 'digilocker_print');

    // Always use portal-registered redirect URI from config (ignore client returnUrl).
    const started = startDigiLockerAuthorization(this.digiLocker);
    const expiresAt = new Date(Date.now() + SESSION_TTL_SECONDS * 1000);

    const session = await this.db.digiLockerSession.create({
      data: {
        deviceId,
        authorizationUrl: started.authorizationUrl,
        state: started.state,
        codeVerifier: started.codeVerifier,
        expiresAt,
        status: DigiLockerSessionStatus.pending,
      },
    });

    await this.audit.record({
      action: 'digilocker.session_started',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'digilocker_session',
      resourceId: session.id,
      correlationId,
    });

    return mapSession(session);
  }

  async getSession(sessionId: string, deviceId: string) {
    const session = await this.requireSession(sessionId, deviceId, false);
    return mapSession(session);
  }

  async cancelSession(sessionId: string, deviceId: string, correlationId?: string) {
    const session = await this.requireSession(sessionId, deviceId, false);
    if (session.status === DigiLockerSessionStatus.expired) {
      return mapSession(session);
    }

    const updated = await this.db.digiLockerSession.update({
      where: { id: sessionId },
      data: {
        status: DigiLockerSessionStatus.expired,
        accessToken: null,
        idToken: null,
        tokenExpiresAt: null,
      },
    });

    await this.audit.record({
      action: 'digilocker.session_cancelled',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'digilocker_session',
      resourceId: session.id,
      correlationId,
    });

    return mapSession(updated);
  }

  async handleOAuthCallback(input: { code?: string; state?: string; error?: string }) {
    if (input.error) {
      if (input.state) {
        await this.db.digiLockerSession.updateMany({
          where: { state: input.state },
          data: { status: DigiLockerSessionStatus.failed },
        });
      }
      throw new AppError('digilocker_oauth_denied', input.error, 400);
    }
    if (!input.code || !input.state) {
      throw new AppError('validation_error', 'Missing code or state', 400);
    }

    const session = await this.db.digiLockerSession.findUnique({ where: { state: input.state } });
    if (!session) {
      throw new AppError('not_found', 'Unknown DigiLocker OAuth state', 404);
    }
    if (session.expiresAt.getTime() < Date.now()) {
      await this.db.digiLockerSession.update({
        where: { id: session.id },
        data: { status: DigiLockerSessionStatus.expired },
      });
      throw new AppError('session_expired', 'DigiLocker session expired', 400);
    }

    const tokens = await this.digiLocker.exchangeCode({
      code: input.code,
      codeVerifier: session.codeVerifier,
    });

    const updated = await this.db.digiLockerSession.update({
      where: { id: session.id },
      data: {
        status: DigiLockerSessionStatus.authorized,
        authorizedAt: new Date(),
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
        tokenExpiresAt: new Date(Date.now() + tokens.expiresIn * 1000),
        consentValidTill: tokens.consentValidTill,
      },
    });

    await this.audit.record({
      action: 'digilocker.session_authorized',
      principalType: 'device',
      principalId: session.deviceId,
      resourceType: 'digilocker_session',
      resourceId: session.id,
    });

    return mapSession(updated);
  }

  async listDocuments(sessionId: string, deviceId: string) {
    const session = await this.requireAuthorizedSession(sessionId, deviceId);
    const items = await this.digiLocker.listAllDocuments(session.accessToken!);
    return {
      items: items.map((doc) => ({
        id: doc.id,
        name: doc.name,
        issuer: doc.issuer,
        mimeType: doc.mimeType,
        doctype: doc.doctype,
        description: doc.description,
        source: doc.source,
      })),
    };
  }

  async printDocument(
    sessionId: string,
    deviceId: string,
    input: PrintDigiLockerInput,
    correlationId?: string,
  ) {
    await this.services.assertEnabled(deviceId, 'digilocker_print');
    const session = await this.requireAuthorizedSession(sessionId, deviceId);

    // documentId is the DigiLocker URI (or synthetic eaadhaar:xml). Do not re-list
    // issued/uploaded here — that triggers DigiLocker rate limits (429).
    const documentUri = input.documentId;
    const title =
      input.title?.trim() ||
      (documentUri === 'eaadhaar:xml' ? 'e-Aadhaar' : 'DigiLocker document');

    const file = await this.digiLocker.downloadFile(session.accessToken!, documentUri);
    const job = await this.printing.createJob(
      {
        source: PrintJobSource.digilocker_print,
        title,
        pageCount: 1,
        deviceId,
        payloadUrl: `/v1/print-jobs/pending/content`,
        digiLockerSessionId: session.id,
        idempotencyKey: input.idempotencyKey ?? `dl-print-${session.id}-${documentUri}`.slice(0, 100),
      },
      'device',
      deviceId,
      correlationId,
    );

    const payloadDir = join(process.cwd(), 'tmp', 'digilocker');
    await mkdir(payloadDir, { recursive: true });
    const payloadPath = join(payloadDir, `${job.id}.pdf`);
    await writeFile(payloadPath, file.bytes);

    const updated = await this.printing.attachPayload(job.id, {
      payloadPath,
      payloadUrl: `/v1/print-jobs/${job.id}/content`,
    });

    await this.audit.record({
      action: 'digilocker.print_requested',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'print_job',
      resourceId: job.id,
      correlationId,
      metadata: { documentId: documentUri, sessionId },
    });

    return updated;
  }

  private async requireAuthorizedSession(sessionId: string, deviceId: string) {
    const session = await this.requireSession(sessionId, deviceId, true);
    if (session.status !== DigiLockerSessionStatus.authorized || !session.accessToken) {
      throw new AppError('session_not_authorized', 'DigiLocker session is not authorized', 400);
    }
    if (session.tokenExpiresAt && session.tokenExpiresAt.getTime() < Date.now()) {
      throw new AppError('session_expired', 'DigiLocker access token expired', 400);
    }
    return session;
  }

  private async requireSession(sessionId: string, deviceId: string, checkExpiry: boolean) {
    const session = await this.db.digiLockerSession.findUnique({ where: { id: sessionId } });
    if (!session) {
      throw new AppError('not_found', 'DigiLocker session not found', 404);
    }
    if (session.deviceId !== deviceId) {
      throw new AppError('forbidden', 'Session belongs to another device', 403);
    }
    if (checkExpiry && session.expiresAt.getTime() < Date.now() && session.status === DigiLockerSessionStatus.pending) {
      await this.db.digiLockerSession.update({
        where: { id: sessionId },
        data: { status: DigiLockerSessionStatus.expired },
      });
      throw new AppError('session_expired', 'DigiLocker session expired', 400);
    }
    return session;
  }
}
