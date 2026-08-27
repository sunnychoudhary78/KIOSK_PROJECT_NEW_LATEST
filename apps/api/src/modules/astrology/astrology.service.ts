import type { Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { Logger } from '../../infrastructure/logging/logger.js';
import type { AstrologyLlmClient } from '../../infrastructure/external/openai.client.js';
import type { VedAstroClient } from '../../infrastructure/external/vedastro.client.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import { ServicesCatalogService } from '../services/services.service.js';
import {
  ASTROLOGY_DISCLAIMER,
  sniffPalmImageMime,
  type ChartSummary,
  type CreateReadingFields,
  type LlmReading,
  type ReadingSubject,
  type UploadedPalm,
} from './astrology.schemas.js';

const MAX_PALM_BYTES = 5 * 1024 * 1024;

export type AstrologyReadingResponse = {
  id: string;
  disclaimer: string;
  subject: ReadingSubject;
  chart: ChartSummary;
  palm: LlmReading['palm'];
  reading: LlmReading['reading'];
};

export class AstrologyService {
  constructor(
    private readonly db: DbClient,
    private readonly vedastro: VedAstroClient,
    private readonly llm: AstrologyLlmClient,
    private readonly audit: AuditService,
    private readonly services: ServicesCatalogService,
    private readonly logger: Logger,
  ) {}

  async createReading(
    deviceId: string,
    fields: CreateReadingFields,
    palm: UploadedPalm,
    correlationId?: string,
  ): Promise<AstrologyReadingResponse> {
    const startedAt = Date.now();
    await this.services.assertEnabled(deviceId, 'astrology');
    const imageMime = this.assertPalm(palm);

    const subject: ReadingSubject = {
      name: fields.name,
      gender: fields.gender,
      dateOfBirth: fields.dateOfBirth,
      birthTime: fields.birthTime,
      birthPlace: fields.birthPlace,
      birthTimeUnknown: Boolean(fields.birthTimeUnknown),
    };

    this.logger.info(
      {
        correlationId,
        deviceId,
        palm: { mime: imageMime, bytes: palm.buffer.length },
        subject,
      },
      '[Astrology] reading started',
    );

    const chart = await this.vedastro.getChart({
      dateOfBirth: subject.dateOfBirth,
      birthTime: subject.birthTime,
      birthPlace: subject.birthPlace,
    });

    this.logger.info(
      {
        correlationId,
        summary: chart.summary,
        planetCount: chart.details.planets.length,
        houseCount: chart.details.houses.length,
      },
      '[Astrology] VedAstro chart ready',
    );

    const generated = await this.llm.generateReading({
      subject,
      chart: chart.details,
      image: { mimeType: imageMime, buffer: palm.buffer },
    });

    const stored = await this.db.astrologyReading.create({
      data: {
        deviceId,
        subject: subject as Prisma.InputJsonValue,
        chart: chart.summary as Prisma.InputJsonValue,
        palm: generated.palm as Prisma.InputJsonValue,
        reading: generated.reading as Prisma.InputJsonValue,
      },
    });

    await this.audit.record({
      action: 'astrology.reading_created',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'astrology_reading',
      resourceId: stored.id,
      correlationId,
      metadata: {
        gender: subject.gender,
        birthTimeUnknown: subject.birthTimeUnknown,
        birthPlace: subject.birthPlace,
      },
    });

    this.logger.info(
      {
        correlationId,
        readingId: stored.id,
        chart: chart.summary,
        durationMs: Date.now() - startedAt,
      },
      '[Astrology] reading stored',
    );

    return {
      id: stored.id,
      disclaimer: ASTROLOGY_DISCLAIMER,
      subject,
      chart: chart.summary,
      palm: generated.palm,
      reading: generated.reading,
    };
  }

  private assertPalm(palm: UploadedPalm): 'image/jpeg' | 'image/png' | 'image/webp' {
    if (palm.size <= 0 || palm.buffer.length === 0) {
      throw new AppError('validation_error', 'Palm image is empty', 400);
    }
    if (palm.size > MAX_PALM_BYTES || palm.buffer.length > MAX_PALM_BYTES) {
      throw new AppError('validation_error', 'Palm image must be 5 MB or smaller', 400);
    }
    const sniffed = sniffPalmImageMime(palm.buffer);
    if (!sniffed) {
      throw new AppError('validation_error', 'Palm image must be JPEG, PNG, or WebP', 400);
    }
    return sniffed;
  }
}
