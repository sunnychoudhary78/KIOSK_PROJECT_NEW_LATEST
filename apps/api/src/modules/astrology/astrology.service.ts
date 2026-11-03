import { PrintJobSource, type Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { Logger } from '../../infrastructure/logging/logger.js';
import {
  NOOP_KUNDALI_INSIGHTS,
  NOOP_LOCALE_BULLETS,
  type AstrologyLlmClient,
} from '../../infrastructure/external/openai.client.js';
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
import { createPrintJobWithPdf } from '../printing/create_print_job_with_pdf.js';
import { assertPrintingAvailable } from '../printing/printing_pause.js';
import { PrintingService } from '../printing/printing.service.js';
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
  type KundaliInsights,
  type LocaleBullets,
  type LlmReading,
  type PrintKundaliBody,
  type PrintMatchBody,
  type PrintReadingBody,
  type PrintTodayBody,
  type ReadingSubject,
  type UploadedPalm,
} from './astrology.schemas.js';
import {
  buildKundaliReportPdf,
  buildMatchReportPdf,
  buildPalmReportPdf,
  buildTodayReportPdf,
} from './astrology_report_pdf.js';

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
  insights: KundaliInsights;
};

export type AstrologyMatchResponse = {
  disclaimer: string;
  accuracyNote?: string;
  groom: ReadingSubject;
  bride: ReadingSubject;
  score: Pick<VedAstroMatchResult, 'total' | 'max' | 'summary' | 'tone'>;
  kutas: VedAstroMatchResult['kutas'];
  insights: LocaleBullets;
};

export type AstrologyTodayResponse = {
  disclaimer: string;
  accuracyNote?: string;
  subject: ReadingSubject;
  asOf: string;
  panchang: VedAstroPanchangaResult;
  dasha: { label: string; levels: string[] };
  insights: LocaleBullets;
};

export class AstrologyService {
  private readonly printing: PrintingService;

  constructor(
    private readonly db: DbClient,
    private readonly vedastro: VedAstroClient,
    private readonly llm: AstrologyLlmClient,
    private readonly audit: AuditService,
    private readonly services: ServicesCatalogService,
    private readonly logger: Logger,
  ) {
    this.printing = new PrintingService(db, audit);
  }

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

    const chart = await this.vedastro.getChart(
      this.toVedAstroBirth(fields, {
        dateOfBirth: subject.dateOfBirth,
        birthTime: subject.birthTime,
        birthPlace: subject.birthPlace,
      }),
    );

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

    const birth = this.toVedAstroBirth(fields, {
      dateOfBirth: subject.dateOfBirth,
      birthTime: subject.birthTime,
      birthPlace: subject.birthPlace,
    });

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

    const chartsPresent = (Object.keys(charts) as KundaliChartType[]).filter(
      (key) => key === 'RasiD1' || key === 'NavamshaD9' || key === 'DashamamshaD10',
    );
    const insights = await this.safeKundaliInsights({
      subject,
      chart: { ...chartResult.details, ...summary },
      style: fields.style,
      chartsPresent,
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
      insights,
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
      this.toVedAstroBirth(fields.groom, {
        dateOfBirth: groom.dateOfBirth,
        birthTime: groom.birthTime,
        birthPlace: groom.birthPlace,
      }),
      this.toVedAstroBirth(fields.bride, {
        dateOfBirth: bride.dateOfBirth,
        birthTime: bride.birthTime,
        birthPlace: bride.birthPlace,
      }),
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

    const score = {
      total: result.total,
      max: result.max,
      summary: result.summary,
      tone: result.tone,
    };
    const insights = await this.safeMatchInsights({
      groom,
      bride,
      score,
      kutas: result.kutas,
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
      score,
      kutas: result.kutas,
      insights,
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
    const birth = this.toVedAstroBirth(fields, {
      dateOfBirth: subject.dateOfBirth,
      birthTime: subject.birthTime,
      birthPlace: subject.birthPlace,
    });
    const asOf = new Date();
    const [panchang, dasha] = await Promise.all([
      this.vedastro.getPanchangaTable({
        birthPlace: subject.birthPlace,
        now: asOf,
        latitude: birth.latitude,
        longitude: birth.longitude,
      }),
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

    const insights = await this.safeTodayInsights({
      subject,
      panchang,
      dasha,
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
      insights,
    };
  }

  async printKundali(deviceId: string, input: PrintKundaliBody, correlationId?: string) {
    await this.services.assertEnabled(deviceId, 'astrology');
    await assertPrintingAvailable(this.db, deviceId);
    const bytes = await buildKundaliReportPdf({
      subject: { ...input.subject, birthTimeUnknown: Boolean(input.subject.birthTimeUnknown) },
      style: input.style,
      chart: input.chart,
      charts: input.charts,
      insights: input.insights,
      locale: input.locale,
      disclaimer: input.disclaimer,
    });
    const job = await createPrintJobWithPdf(
      this.printing,
      {
        source: PrintJobSource.astrology_print,
        title: `Kundali — ${input.subject.name}`,
        deviceId,
        bytes,
        folder: 'astrology',
        idempotencyKey:
          input.idempotencyKey ??
          `ast-kundali-${deviceId}-${input.subject.name}-${Date.now()}`.slice(0, 100),
      },
      'device',
      correlationId,
    );
    await this.audit.record({
      action: 'astrology.kundali_print_requested',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'print_job',
      resourceId: job.id,
      correlationId,
    });
    return job;
  }

  async printMatch(deviceId: string, input: PrintMatchBody, correlationId?: string) {
    await this.services.assertEnabled(deviceId, 'astrology');
    await assertPrintingAvailable(this.db, deviceId);
    const bytes = await buildMatchReportPdf({
      groom: { ...input.groom, birthTimeUnknown: Boolean(input.groom.birthTimeUnknown) },
      bride: { ...input.bride, birthTimeUnknown: Boolean(input.bride.birthTimeUnknown) },
      score: input.score,
      kutas: input.kutas,
      accuracyNote: input.accuracyNote,
      insightBullets: input.insightBullets,
      locale: input.locale,
      disclaimer: input.disclaimer,
    });
    const job = await createPrintJobWithPdf(
      this.printing,
      {
        source: PrintJobSource.astrology_print,
        title: `Match Kundali — ${input.groom.name} & ${input.bride.name}`,
        deviceId,
        bytes,
        folder: 'astrology',
        idempotencyKey:
          input.idempotencyKey ??
          `ast-match-${deviceId}-${input.groom.name}-${input.bride.name}-${Date.now()}`.slice(0, 100),
      },
      'device',
      correlationId,
    );
    await this.audit.record({
      action: 'astrology.match_print_requested',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'print_job',
      resourceId: job.id,
      correlationId,
    });
    return job;
  }

  async printReading(deviceId: string, input: PrintReadingBody, correlationId?: string) {
    await this.services.assertEnabled(deviceId, 'astrology');
    await assertPrintingAvailable(this.db, deviceId);
    const bytes = await buildPalmReportPdf({
      subject: { ...input.subject, birthTimeUnknown: Boolean(input.subject.birthTimeUnknown) },
      chart: input.chart,
      palm: input.palm,
      reading: input.reading,
      palmJpegBase64: input.palmJpegBase64,
      disclaimer: input.disclaimer,
    });
    const job = await createPrintJobWithPdf(
      this.printing,
      {
        source: PrintJobSource.astrology_print,
        title: `Palm Reading — ${input.subject.name}`,
        deviceId,
        bytes,
        folder: 'astrology',
        idempotencyKey:
          input.idempotencyKey ??
          `ast-palm-${deviceId}-${input.subject.name}-${Date.now()}`.slice(0, 100),
      },
      'device',
      correlationId,
    );
    await this.audit.record({
      action: 'astrology.reading_print_requested',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'print_job',
      resourceId: job.id,
      correlationId,
    });
    return job;
  }

  async printToday(deviceId: string, input: PrintTodayBody, correlationId?: string) {
    await this.services.assertEnabled(deviceId, 'astrology');
    await assertPrintingAvailable(this.db, deviceId);
    const bytes = await buildTodayReportPdf({
      subject: { ...input.subject, birthTimeUnknown: Boolean(input.subject.birthTimeUnknown) },
      asOf: input.asOf,
      panchang: input.panchang,
      dasha: input.dasha,
      accuracyNote: input.accuracyNote,
      insightBullets: input.insightBullets,
      locale: input.locale,
      disclaimer: input.disclaimer,
    });
    const job = await createPrintJobWithPdf(
      this.printing,
      {
        source: PrintJobSource.astrology_print,
        title: `Today & Panchang — ${input.subject.name}`,
        deviceId,
        bytes,
        folder: 'astrology',
        idempotencyKey:
          input.idempotencyKey ??
          `ast-today-${deviceId}-${input.subject.name}-${Date.now()}`.slice(0, 100),
      },
      'device',
      correlationId,
    );
    await this.audit.record({
      action: 'astrology.today_print_requested',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'print_job',
      resourceId: job.id,
      correlationId,
    });
    return job;
  }

  private async safeKundaliInsights(
    input: Parameters<AstrologyLlmClient['generateKundaliInsights']>[0],
  ): Promise<KundaliInsights> {
    try {
      return await this.llm.generateKundaliInsights(input);
    } catch (error) {
      this.logger.warn({ err: error }, '[Astrology] kundali insights failed; using fallback');
      const out: KundaliInsights = {};
      for (const key of input.chartsPresent) {
        const block = NOOP_KUNDALI_INSIGHTS[key];
        if (block) out[key] = block;
      }
      return out;
    }
  }

  private async safeMatchInsights(
    input: Parameters<AstrologyLlmClient['generateMatchInsights']>[0],
  ): Promise<LocaleBullets> {
    try {
      return await this.llm.generateMatchInsights(input);
    } catch (error) {
      this.logger.warn({ err: error }, '[Astrology] match insights failed; using fallback');
      return NOOP_LOCALE_BULLETS;
    }
  }

  private async safeTodayInsights(
    input: Parameters<AstrologyLlmClient['generateTodayInsights']>[0],
  ): Promise<LocaleBullets> {
    try {
      return await this.llm.generateTodayInsights(input);
    } catch (error) {
      this.logger.warn({ err: error }, '[Astrology] today insights failed; using fallback');
      return NOOP_LOCALE_BULLETS;
    }
  }

  private toVedAstroBirth(
    fields: { latitude?: number; longitude?: number },
    birth: { dateOfBirth: string; birthTime: string; birthPlace: string },
  ) {
    return {
      ...birth,
      ...(typeof fields.latitude === 'number' && typeof fields.longitude === 'number'
        ? { latitude: fields.latitude, longitude: fields.longitude }
        : {}),
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
