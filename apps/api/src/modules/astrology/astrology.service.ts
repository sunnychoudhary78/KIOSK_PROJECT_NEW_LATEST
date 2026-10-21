import type { Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { Logger } from '../../infrastructure/logging/logger.js';
import type { AstrologyLlmClient } from '../../infrastructure/external/openai.client.js';
import {
  KUNDALI_CHART_META,
  KUNDALI_PREFETCH_TYPES,
  type KundaliChartType,
  type VedAstroClient,
  type VedAstroMatchResult,
  type VedAstroPanchangaResult,
} from '../../infrastructure/external/vedastro.client.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import { ServicesCatalogService } from '../services/services.service.js';
import {
  ASTROLOGY_DISCLAIMER,
  sniffPalmImageMime,
  type ChartSummary,
  type CreateKundaliBody,
  type CreateMatchBody,
  type CreateReadingFields,
  type CreateTodayBody,
  type KundaliChartEntry,
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

export type AstrologyKundaliResponse = {
  disclaimer: string;
  subject: ReadingSubject;
  style: 'north' | 'south';
  chartType: 'RasiD1';
  svg: string;
  chart: ChartSummary;
  charts: Partial<Record<KundaliChartType, KundaliChartEntry>>;
};

export type AstrologyMatchResponse = {
  disclaimer: string;
  accuracyNote?: string;
  groom: ReadingSubject;
  bride: ReadingSubject;
  score: Pick<VedAstroMatchResult, 'total' | 'max' | 'summary' | 'tone'>;
  kutas: VedAstroMatchResult['kutas'];
};

export type AstrologyTodayResponse = {
  disclaimer: string;
  accuracyNote?: string;
  subject: ReadingSubject;
  asOf: string;
  panchang: VedAstroPanchangaResult;
  dasha: { label: string; levels: string[] };
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

  async createKundali(
    deviceId: string,
    fields: CreateKundaliBody,
    correlationId?: string,
  ): Promise<AstrologyKundaliResponse> {
    const startedAt = Date.now();
    await this.services.assertEnabled(deviceId, 'astrology');

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
        style: fields.style,
        chartType: fields.chartType,
        subject,
      },
      '[Astrology] kundali started',
    );

    const birth = {
      dateOfBirth: subject.dateOfBirth,
      birthTime: subject.birthTime,
      birthPlace: subject.birthPlace,
    };

    const [chartResult, dasaResult, ...svgResults] = await Promise.all([
      this.vedastro.getChart(birth),
      this.vedastro.getDasaForNow(birth).then(
        (dasa) => dasa,
        (error: unknown) => {
          this.logger.warn({ err: error }, '[Astrology] DasaForNow failed; continuing');
          return null;
        },
      ),
      ...KUNDALI_PREFETCH_TYPES.map((chartType) =>
        this.vedastro
          .getKundaliSvg({ ...birth, style: fields.style, chartType })
          .then(
            (svg) => ({ chartType, svg }),
            (error: unknown) => {
              this.logger.warn({ err: error, chartType }, '[Astrology] chart SVG failed');
              return { chartType, svg: null as null };
            },
          ),
      ),
    ]);

    const charts: AstrologyKundaliResponse['charts'] = {};
    for (const entry of svgResults) {
      if (!entry.svg) {
        continue;
      }
      const meta = KUNDALI_CHART_META[entry.chartType];
      charts[entry.chartType] = {
        svg: entry.svg.svg,
        title: meta.title,
        subtitle: meta.subtitle,
      };
    }

    const primary = charts.RasiD1;
    if (!primary) {
      throw new AppError('vedastro_failed', 'Unable to generate birth kundali chart', 502);
    }

    const summary: ChartSummary = {
      ...chartResult.summary,
      ...(dasaResult?.label ? { currentDasha: dasaResult.label } : {}),
    };

    await this.audit.record({
      action: 'astrology.kundali_generated',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'astrology_kundali',
      correlationId,
      metadata: {
        style: fields.style,
        chartTypes: Object.keys(charts),
        birthPlace: subject.birthPlace,
        birthTimeUnknown: subject.birthTimeUnknown,
        currentDasha: summary.currentDasha,
      },
    });

    this.logger.info(
      {
        correlationId,
        style: fields.style,
        chart: summary,
        chartTypes: Object.keys(charts),
        svgBytes: primary.svg.length,
        durationMs: Date.now() - startedAt,
      },
      '[Astrology] kundali ready',
    );

    return {
      disclaimer: ASTROLOGY_DISCLAIMER,
      subject,
      style: fields.style,
      chartType: 'RasiD1',
      svg: primary.svg,
      chart: summary,
      charts,
    };
  }

  async createMatch(
    deviceId: string,
    fields: CreateMatchBody,
    correlationId?: string,
  ): Promise<AstrologyMatchResponse> {
    const startedAt = Date.now();
    await this.services.assertEnabled(deviceId, 'astrology');

    const groom: ReadingSubject = {
      ...fields.groom,
      gender: 'male',
      birthTimeUnknown: Boolean(fields.groom.birthTimeUnknown),
    };
    const bride: ReadingSubject = {
      ...fields.bride,
      gender: 'female',
      birthTimeUnknown: Boolean(fields.bride.birthTimeUnknown),
    };
    const result = await this.vedastro.getMatchReport(
      {
        dateOfBirth: groom.dateOfBirth,
        birthTime: groom.birthTime,
        birthPlace: groom.birthPlace,
      },
      {
        dateOfBirth: bride.dateOfBirth,
        birthTime: bride.birthTime,
        birthPlace: bride.birthPlace,
      },
    );

    await this.audit.record({
      action: 'astrology.match_generated',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'astrology_match',
      correlationId,
      metadata: {
        score: result.total,
        groomBirthPlace: groom.birthPlace,
        brideBirthPlace: bride.birthPlace,
        birthTimeUnknown: groom.birthTimeUnknown || bride.birthTimeUnknown,
      },
    });

    this.logger.info(
      {
        correlationId,
        score: result.total,
        durationMs: Date.now() - startedAt,
      },
      '[Astrology] kundali match ready',
    );

    return {
      disclaimer: ASTROLOGY_DISCLAIMER,
      ...(groom.birthTimeUnknown || bride.birthTimeUnknown
        ? { accuracyNote: 'An unknown birth time was set to 12:00; compatibility may be less precise.' }
        : {}),
      groom,
      bride,
      score: {
        total: result.total,
        max: result.max,
        summary: result.summary,
        tone: result.tone,
      },
      kutas: result.kutas,
    };
  }

  async createToday(
    deviceId: string,
    fields: CreateTodayBody,
    correlationId?: string,
  ): Promise<AstrologyTodayResponse> {
    const startedAt = Date.now();
    await this.services.assertEnabled(deviceId, 'astrology');

    const subject: ReadingSubject = {
      name: fields.name,
      gender: fields.gender,
      dateOfBirth: fields.dateOfBirth,
      birthTime: fields.birthTime,
      birthPlace: fields.birthPlace,
      birthTimeUnknown: Boolean(fields.birthTimeUnknown),
    };
    const birth = {
      dateOfBirth: subject.dateOfBirth,
      birthTime: subject.birthTime,
      birthPlace: subject.birthPlace,
    };
    const asOf = new Date();
    const [panchang, dasha] = await Promise.all([
      this.vedastro.getPanchangaTable({ birthPlace: subject.birthPlace, now: asOf }),
      this.vedastro.getDasaForNow(birth),
    ]);
    if (!dasha.label) {
      throw new AppError('vedastro_failed', 'Unable to compute current dasha', 502);
    }

    await this.audit.record({
      action: 'astrology.today_generated',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'astrology_today',
      correlationId,
      metadata: {
        birthPlace: subject.birthPlace,
        birthTimeUnknown: subject.birthTimeUnknown,
        dasha: dasha.label,
        weekday: panchang.weekday,
      },
    });

    this.logger.info(
      {
        correlationId,
        dasha: dasha.label,
        durationMs: Date.now() - startedAt,
      },
      '[Astrology] today periods ready',
    );

    return {
      disclaimer: ASTROLOGY_DISCLAIMER,
      ...(subject.birthTimeUnknown
        ? {
            accuracyNote:
              'An unknown birth time was set to 12:00; current dasha may be less precise.',
          }
        : {}),
      subject,
      asOf: asOf.toISOString(),
      panchang,
      dasha,
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
