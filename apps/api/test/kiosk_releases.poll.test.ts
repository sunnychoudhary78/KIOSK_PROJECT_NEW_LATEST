import { describe, expect, it, vi } from 'vitest';
import express from 'express';
import request from 'supertest';
import { KioskAppReleaseStatus } from '@prisma/client';
import { registerKioskReleasesModule } from '../src/modules/kiosk_releases/index.js';
import { errorHandler } from '../src/infrastructure/http/error-handler.js';
import { correlationIdMiddleware } from '../src/infrastructure/http/correlation.js';
import type { Logger } from '../src/infrastructure/logging/logger.js';
import type { AppDeps } from '../src/types/deps.js';
import type { ObjectStorageClient } from '../src/infrastructure/storage/s3.client.js';

const releaseId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const objectKey = 'kiosk-releases/1.2.0/file.zip';
const sha256 = 'b'.repeat(64);

const silentLogger = {
  error: vi.fn(),
  warn: vi.fn(),
  info: vi.fn(),
  debug: vi.fn(),
  fatal: vi.fn(),
  trace: vi.fn(),
  child: vi.fn(),
} as unknown as Logger;

function buildApp(deps: AppDeps) {
  const app = express();
  app.use(correlationIdMiddleware);
  app.use(express.json());
  const router = express.Router();
  registerKioskReleasesModule(router, deps);
  app.use('/v1', router);
  app.use(errorHandler(silentLogger));
  return app;
}

function baseDeps(overrides: Partial<AppDeps> = {}): AppDeps {
  return {
    config: {
      kioskUpdateKey: 'test-update-key',
    } as AppDeps['config'],
    db: {
      kioskAppRelease: {
        findFirst: vi.fn(async () => ({
          id: releaseId,
          version: '1.2.0',
          objectKey,
          contentType: 'application/zip',
          byteSize: BigInt(4096),
          sha256,
          status: KioskAppReleaseStatus.active,
          createdByAdminId: null,
          uploadedAt: new Date(),
          activatedAt: new Date(),
          createdAt: new Date(),
          updatedAt: new Date(),
        })),
      },
    } as unknown as AppDeps['db'],
    objectStorage: {
      isConfigured: () => true,
      presignPut: vi.fn(),
      presignGet: vi.fn(async () => ({
        url: 'https://r2.example/download',
        expiresAt: new Date('2026-04-10T12:15:00.000Z'),
      })),
      headObject: vi.fn(),
      deleteObject: vi.fn(),
    } as ObjectStorageClient,
    auditService: { record: vi.fn() } as unknown as AppDeps['auditService'],
    logger: silentLogger,
    digiLocker: {} as AppDeps['digiLocker'],
    sms: {} as AppDeps['sms'],
    vedastro: {} as AppDeps['vedastro'],
    astrologyLlm: {} as AppDeps['astrologyLlm'],
    ...overrides,
  };
}

describe('GET /v1/kiosk-updates/current', () => {
  it('returns 401 without X-Update-Key', async () => {
    const app = buildApp(baseDeps());
    const res = await request(app).get('/v1/kiosk-updates/current');
    expect(res.status).toBe(401);
    expect(res.body.code).toBe('unauthorized');
  });

  it('returns 401 with the wrong key', async () => {
    const app = buildApp(baseDeps());
    const res = await request(app)
      .get('/v1/kiosk-updates/current')
      .set('X-Update-Key', 'wrong');
    expect(res.status).toBe(401);
  });

  it('returns 503 when the update key is not configured', async () => {
    const app = buildApp(
      baseDeps({
        config: { kioskUpdateKey: '' } as AppDeps['config'],
      }),
    );
    const res = await request(app)
      .get('/v1/kiosk-updates/current')
      .set('X-Update-Key', 'anything');
    expect(res.status).toBe(503);
    expect(res.body.code).toBe('update_key_not_configured');
  });

  it('returns the active release download payload', async () => {
    const app = buildApp(baseDeps());
    const res = await request(app)
      .get('/v1/kiosk-updates/current')
      .set('X-Update-Key', 'test-update-key');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      version: '1.2.0',
      downloadUrl: 'https://r2.example/download',
      sha256,
      byteSize: 4096,
      expiresAt: '2026-04-10T12:15:00.000Z',
    });
  });
});
