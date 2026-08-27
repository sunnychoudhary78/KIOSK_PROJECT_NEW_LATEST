import { describe, expect, it, vi } from 'vitest';
import { AstrologyService } from '../src/modules/astrology/astrology.service.js';
import { ASTROLOGY_DISCLAIMER, sniffPalmImageMime } from '../src/modules/astrology/astrology.schemas.js';
import { NOOP_ASTROLOGY_READING } from '../src/infrastructure/external/openai.client.js';
import { AppError } from '../src/shared/errors.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import type { ServicesCatalogService } from '../src/modules/services/services.service.js';
import type { Logger } from '../src/infrastructure/logging/logger.js';
import type { VedAstroClient } from '../src/infrastructure/external/vedastro.client.js';
import type { AstrologyLlmClient } from '../src/infrastructure/external/openai.client.js';

const silentLogger = { info: vi.fn(), warn: vi.fn(), error: vi.fn() } as unknown as Logger;

describe('AstrologyService.createReading', () => {
  const fields = {
    name: 'Asha',
    gender: 'female' as const,
    dateOfBirth: '1992-03-18',
    birthTime: '12:00',
    birthPlace: 'Jaipur',
    birthTimeUnknown: true,
  };
  const jpegBuffer = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, ...Buffer.alloc(24, 1)]);
  const palm = {
    originalname: 'palm.jpg',
    mimetype: 'image/jpeg',
    size: jpegBuffer.length,
    buffer: jpegBuffer,
  };

  function setup(overrides?: { enabled?: boolean }) {
    const db = {
      astrologyReading: {
        create: vi.fn(async ({ data }: { data: { deviceId: string } }) => ({
          id: '11111111-1111-1111-1111-111111111111',
          ...data,
        })),
      },
    };
    const vedastro: VedAstroClient = {
      getChart: vi.fn(async () => ({
        summary: { sunSign: 'Pisces', moonSign: 'Taurus' },
        details: { sunSign: 'Pisces', moonSign: 'Taurus', planets: [], houses: [] },
      })),
    };
    const llm: AstrologyLlmClient = {
      generateReading: vi.fn(async () => NOOP_ASTROLOGY_READING),
    };
    const audit = { record: vi.fn(async () => undefined) };
    const services = {
      assertEnabled: vi.fn(async () => {
        if (overrides?.enabled === false) {
          throw new AppError('service_disabled', 'Service astrology is disabled for this device', 403);
        }
      }),
    };

    const service = new AstrologyService(
      db as unknown as DbClient,
      vedastro,
      llm,
      audit as unknown as AuditService,
      services as unknown as ServicesCatalogService,
      silentLogger,
    );
    return { service, db, vedastro, llm, audit, services };
  }

  it('persists metadata and returns a structured reading', async () => {
    const { service, vedastro, llm, audit } = setup();
    const result = await service.createReading('device-1', fields, palm, 'corr-1');
    expect(result.id).toBe('11111111-1111-1111-1111-111111111111');
    expect(result.disclaimer).toBe(ASTROLOGY_DISCLAIMER);
    expect(result.chart.sunSign).toBe('Pisces');
    expect(result.palm.summary).toBe(NOOP_ASTROLOGY_READING.palm.summary);
    expect(vedastro.getChart).toHaveBeenCalledOnce();
    expect(llm.generateReading).toHaveBeenCalledWith(
      expect.objectContaining({
        chart: expect.objectContaining({
          sunSign: 'Pisces',
          moonSign: 'Taurus',
          planets: [],
          houses: [],
        }),
      }),
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'astrology.reading_created',
        resourceId: result.id,
      }),
    );
  });

  it('rejects non-image palms before calling vendors', async () => {
    const { service, vedastro } = setup();
    await expect(
      service.createReading('device-1', fields, {
        originalname: 'palm.bin',
        mimetype: 'application/pdf',
        size: 12,
        buffer: Buffer.from('not-a-real-jpeg'),
      }),
    ).rejects.toMatchObject({ code: 'validation_error' });
    expect(vedastro.getChart).not.toHaveBeenCalled();
  });

  it('accepts JPEG magic bytes even when multer reports octet-stream', async () => {
    const { service, llm } = setup();
    await service.createReading('device-1', fields, {
      originalname: 'palm.jpg',
      mimetype: 'application/octet-stream',
      size: jpegBuffer.length,
      buffer: jpegBuffer,
    });
    expect(llm.generateReading).toHaveBeenCalledWith(
      expect.objectContaining({
        image: expect.objectContaining({ mimeType: 'image/jpeg' }),
      }),
    );
  });

  it('does not call vendors when the service is disabled', async () => {
    const { service, vedastro, llm } = setup({ enabled: false });
    await expect(service.createReading('device-1', fields, palm)).rejects.toMatchObject({
      code: 'service_disabled',
    });
    expect(vedastro.getChart).not.toHaveBeenCalled();
    expect(llm.generateReading).not.toHaveBeenCalled();
  });
});
