import { PaymentStatus, PrintColorMode, PrintJobSource, type Prisma } from '@prisma/client';
import type { AppConfig } from '../../config/index.js';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { Logger } from '../../infrastructure/logging/logger.js';
import type { SmsClient } from '../../infrastructure/external/sms.client.js';
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
import {
  generateNumericOtp,
  hashOtp,
  normalizePhone,
  sanitizeOtpDeliveryError,
} from '../../shared/otp.js';
import type { AuditService } from '../audit/audit.service.js';
import { PaymentsService } from '../payments/payments.service.js';
import {
  RazorpayClient,
  verifyPaymentSignature,
} from '../payments/razorpay.client.js';
import { PlatformSettingsService } from '../platform_settings/platform_settings.service.js';
import { PrintQuotaService } from '../print_quota/print_quota.service.js';
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
import {
  createKundaliPhoneProofToken,
  verifyKundaliPhoneProofToken,
} from './kundali_phone_proof.js';

const MAX_PALM_BYTES = 5 * 1024 * 1024;
const kundaliPhoneOtpCooldownUntil = new Map<string, number>();

const kundaliQuotaDeviceSelect = {
  kundaliColorPrintChargeRupees: true,
  maxPagesPerSession: true,
  freePagesPerSession: true,
  extraPageChargeRupees: true,
  freeColorPagesPerSession: true,
  extraColorPageChargeRupees: true,
  freeDisabledFromLocal: true,
  freeDisabledToLocal: true,
} as const;

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
  private readonly quota: PrintQuotaService;
  private readonly settings: PlatformSettingsService;

  constructor(
    private readonly db: DbClient,
    private readonly vedastro: VedAstroClient,
    private readonly llm: AstrologyLlmClient,
    private readonly audit: AuditService,
    private readonly services: ServicesCatalogService,
    private readonly logger: Logger,
    private readonly config: AppConfig,
    private readonly razorpay: RazorpayClient,
    private readonly payments: PaymentsService,
    private readonly sms: SmsClient,
  ) {
    this.printing = new PrintingService(db, audit);
    this.quota = new PrintQuotaService(db, audit);
    this.settings = new PlatformSettingsService(db, audit);
  }

  async getKundaliPrintOptions(deviceId: string) {
    await this.services.assertEnabled(deviceId, 'astrology');
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { kundaliColorPrintChargeRupees: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }
    return {
      chargeRupees: Math.max(0, device.kundaliColorPrintChargeRupees ?? 0),
    };
  }

  async requestKundaliPhoneOtp(deviceId: string, phoneRaw: string, correlationId?: string) {
    await this.services.assertEnabled(deviceId, 'astrology');
    let phone: string;
    try {
      phone = normalizePhone(phoneRaw);
    } catch {
      throw new AppError('invalid_phone', 'Enter a valid 10-digit mobile number', 400);
    }

    const authConfig = await this.settings.getCitizenAuthConfig();
    const cooldownMs = authConfig.requestCooldownSeconds * 1000;
    const until = kundaliPhoneOtpCooldownUntil.get(phone) ?? 0;
    if (Date.now() < until) {
      throw new AppError('otp_cooldown', 'Please wait before requesting another OTP', 429);
    }

    const code = generateNumericOtp(authConfig.otpLength);
    const expiresAt = new Date(Date.now() + authConfig.ttlSeconds * 1000);
    await this.db.phoneOtpSession.upsert({
      where: { phone },
      create: { phone, codeHash: hashOtp(code), expiresAt, attemptCount: 0 },
      update: { codeHash: hashOtp(code), expiresAt, attemptCount: 0 },
    });

    try {
      await this.sms.sendOtp(phone, code, authConfig.ttlSeconds);
    } catch (error) {
      await this.db.phoneOtpSession.delete({ where: { phone } }).catch(() => undefined);
      throw new AppError('sms_failed', sanitizeOtpDeliveryError(error), 502);
    }

    kundaliPhoneOtpCooldownUntil.set(phone, Date.now() + cooldownMs);
    await this.audit.record({
      action: 'astrology.kundali_phone_otp_requested',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'device',
      resourceId: deviceId,
      correlationId,
      metadata: { phoneSuffix: phone.slice(-4) },
    });

    const includeDevOtp =
      this.config.env === 'local' || this.config.env === 'test' || this.config.env === 'dev';
    return {
      message: 'OTP sent successfully',
      expiresAt: expiresAt.toISOString(),
      ...(includeDevOtp ? { devOtp: code } : {}),
    };
  }

  async verifyKundaliPhoneOtp(
    deviceId: string,
    phoneRaw: string,
    otp: string,
    correlationId?: string,
  ) {
    await this.services.assertEnabled(deviceId, 'astrology');
    let phone: string;
    try {
      phone = normalizePhone(phoneRaw);
    } catch {
      throw new AppError('invalid_phone', 'Enter a valid 10-digit mobile number', 400);
    }

    const authConfig = await this.settings.getCitizenAuthConfig();
    const otpSession = await this.db.phoneOtpSession.findUnique({ where: { phone } });
    if (!otpSession) {
      throw new AppError('otp_invalid', 'Invalid or expired OTP', 400);
    }
    if (otpSession.attemptCount >= authConfig.maxVerifyAttempts) {
      await this.db.phoneOtpSession.delete({ where: { phone } }).catch(() => undefined);
      throw new AppError('otp_locked', 'Too many invalid attempts. Request a new OTP.', 400);
    }
    if (otpSession.expiresAt.getTime() < Date.now()) {
      await this.db.phoneOtpSession.delete({ where: { phone } }).catch(() => undefined);
      throw new AppError('otp_expired', 'OTP has expired', 400);
    }
    if (otpSession.codeHash !== hashOtp(otp)) {
      await this.db.phoneOtpSession.update({
        where: { phone },
        data: { attemptCount: { increment: 1 } },
      });
      throw new AppError('otp_invalid', 'Invalid or expired OTP', 400);
    }

    await this.db.phoneOtpSession.delete({ where: { phone } });

    const eligibility = await this.evaluateKundaliFreeEligibility(deviceId, phone);
    const phoneProofToken = createKundaliPhoneProofToken({
      deviceId,
      phone,
      jwtSecret: this.config.auth.jwtSecret,
    });

    await this.audit.record({
      action: 'astrology.kundali_phone_otp_verified',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'device',
      resourceId: deviceId,
      correlationId,
      metadata: {
        phoneSuffix: phone.slice(-4),
        society: eligibility.society,
        freeEligible: eligibility.freeEligible,
      },
    });

    return {
      phoneProofToken,
      society: eligibility.society,
      freeEligible: eligibility.freeEligible,
      remainingColor: eligibility.remainingColor,
      message: eligibility.message,
    };
  }

  private async evaluateKundaliFreeEligibility(deviceId: string, phone: string) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: kundaliQuotaDeviceSelect,
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const remaining = await this.quota.getRemaining(phone, 'color');
    if (!remaining.society) {
      return {
        society: false,
        freeEligible: false,
        remainingColor: remaining.remaining,
        periodKey: remaining.periodKey,
        message: 'This number isn’t on the society free list. Continue with payment.',
      };
    }

    const effective = await this.quota.computeEffectiveFree({
      phone,
      device,
      mode: 'color',
      pageCount: 1,
    });

    if (effective.freeDisabledNow) {
      return {
        society: true,
        freeEligible: false,
        remainingColor: effective.remainingBefore,
        periodKey: effective.periodKey,
        message: 'Free prints are paused on this kiosk right now. Continue with payment.',
      };
    }
    if (effective.freePages < 1) {
      return {
        society: true,
        freeEligible: false,
        remainingColor: effective.remainingBefore,
        periodKey: effective.periodKey,
        message: 'No free color pages left. Continue with payment.',
      };
    }

    return {
      society: true,
      freeEligible: true,
      remainingColor: effective.remainingBefore,
      periodKey: effective.periodKey,
      message: null as string | null,
    };
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
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: kundaliQuotaDeviceSelect,
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }
    const chargeRupees = Math.max(0, device.kundaliColorPrintChargeRupees ?? 0);

    let freePhone: string | null = null;
    let freePeriodKey: string | null = null;
    if (chargeRupees > 0 && input.phoneProofToken) {
      const proof = verifyKundaliPhoneProofToken({
        token: input.phoneProofToken,
        deviceId,
        jwtSecret: this.config.auth.jwtSecret,
      });
      if (!proof) {
        // Wrong-device or corrupt token → reject; expired/invalid for free → fall through to paid.
        // Distinguishing: if signature fails for another device id inside payload, verify returns null.
        // Treat null as paid path (expired or bad). Only 403 if payload device mismatches after parse —
        // verify already returns null for mismatch. Paid path is fine.
      } else {
        const eligibility = await this.evaluateKundaliFreeEligibility(deviceId, proof.phone);
        if (eligibility.freeEligible) {
          freePhone = proof.phone;
          freePeriodKey = eligibility.periodKey;
        }
      }
    }

    if (chargeRupees > 0 && !freePhone && (!this.config.razorpay.keyId || !this.config.razorpay.keySecret)) {
      throw new AppError(
        'payments_not_configured',
        'Paid printing is not available on this kiosk right now',
        503,
      );
    }

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
        title: `Kundali - ${input.subject.name}`,
        deviceId,
        bytes,
        folder: 'astrology',
        printColorMode: PrintColorMode.color,
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
      metadata: freePhone
        ? { freeColorPage: true, phoneSuffix: freePhone.slice(-4) }
        : { freeColorPage: false },
    });

    if (chargeRupees <= 0 || freePhone) {
      if (freePhone && freePeriodKey) {
        await this.quota.reserveFreePages({
          phone: freePhone,
          mode: 'color',
          pages: 1,
          periodKey: freePeriodKey,
          printJobId: job.id,
        });
      }
      return {
        ...job,
        paymentRequired: false,
        amountPaise: 0,
        currency: 'INR',
        paymentId: null,
        checkoutToken: null,
        checkoutUrl: null,
        qrImageUrl: null,
        freePages: freePhone ? 1 : 0,
      };
    }

    const amountPaise = chargeRupees * 100;
    const nowMs = Date.now();
    const windowMs = this.config.payments.windowMinutes * 60_000;
    // Razorpay single-use QR: close_by between +2 minutes and +2 hours.
    const closeByMs = Math.min(
      Math.max(nowMs + windowMs, nowMs + 2 * 60_000),
      nowMs + 2 * 60 * 60_000,
    );
    const closeByUnix = Math.floor(closeByMs / 1000);

    const qr = await this.razorpay.createUpiQrCode({
      amountPaise,
      description: `Kundali color print - ${input.subject.name}`.slice(0, 512),
      name: 'Kundali color print',
      closeByUnix,
      notes: {
        print_job_id: job.id,
        device_id: deviceId,
        kind: 'kundali_color_print',
      },
    });

    const expiresAt = new Date((qr.closeBy || closeByUnix) * 1000);

    const payment = await this.db.payment.create({
      data: {
        printJobId: job.id,
        status: PaymentStatus.PENDING,
        pageCount: job.pageCount ?? 1,
        freePages: 0,
        extraPages: 1,
        printColorMode: PrintColorMode.color,
        amountPaise,
        currency: 'INR',
        razorpayQrCodeId: qr.id,
        qrImageUrl: qr.imageUrl,
        expiresAt,
      },
    });

    await this.audit.record({
      action: 'payment.qr_created',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'payment',
      resourceId: payment.id,
      correlationId,
      metadata: {
        printJobId: job.id,
        razorpayQrCodeId: qr.id,
        amountPaise,
      },
    });

    return {
      ...job,
      paymentRequired: true,
      amountPaise,
      currency: 'INR',
      paymentId: payment.id,
      checkoutToken: null,
      checkoutUrl: null,
      qrImageUrl: qr.imageUrl,
    };
  }

  async getPrintCheckout(token: string) {
    const payment = await this.findCheckoutPayment(token);
    return this.toCheckoutPublic(payment);
  }

  async getPrintJobPayment(deviceId: string, jobId: string) {
    const job = await this.db.printJob.findUnique({
      where: { id: jobId },
      include: { payment: true },
    });
    if (!job || (job.deviceId && job.deviceId !== deviceId)) {
      throw new AppError('not_found', 'Print job not found', 404);
    }
    if (!job.payment) {
      return {
        paymentRequired: false,
        status: 'PAID' as const,
        amountPaise: 0,
        currency: 'INR',
        paidAt: null,
        expiresAt: null,
      };
    }
    const payment = await this.expireIfNeeded(job.payment);
    return {
      paymentRequired: payment.amountPaise > 0,
      status: payment.status,
      amountPaise: payment.amountPaise,
      currency: payment.currency,
      paidAt: payment.paidAt?.toISOString() ?? null,
      expiresAt: payment.expiresAt.toISOString(),
      checkoutToken: payment.checkoutToken,
      checkoutUrl: payment.checkoutToken
        ? `${this.config.printWeb.publicUrl}/astrology-print/${payment.checkoutToken}`
        : null,
      qrImageUrl: payment.qrImageUrl ?? null,
    };
  }

  async createPrintCheckoutOrder(token: string, correlationId?: string) {
    let payment = await this.findCheckoutPayment(token);
    payment = await this.expireIfNeeded(payment);
    if (payment.status === PaymentStatus.PAID) {
      return {
        alreadyPaid: true,
        printReady: true,
        payment: this.toCheckoutPublic(payment),
        razorpay_order_id: payment.razorpayOrderId,
        razorpay_key_id: this.razorpay.getKeyId(),
      };
    }
    if (payment.status !== PaymentStatus.PENDING && payment.status !== PaymentStatus.FAILED) {
      throw new AppError('payment_unavailable', 'This print cannot be paid', 400);
    }

    if (payment.razorpayOrderId && payment.status === PaymentStatus.PENDING) {
      return {
        alreadyPaid: false,
        printReady: false,
        payment: this.toCheckoutPublic(payment),
        razorpay_order_id: payment.razorpayOrderId,
        razorpay_key_id: this.razorpay.getKeyId(),
      };
    }

    const order = await this.razorpay.createOrder({
      amountPaise: payment.amountPaise,
      currency: payment.currency,
      receipt: payment.id.slice(0, 40),
      notes: {
        print_job_id: payment.printJobId ?? '',
        payment_id: payment.id,
        kind: 'kundali_color_print',
      },
    });

    payment = await this.db.payment.update({
      where: { id: payment.id },
      data: {
        status: PaymentStatus.PENDING,
        razorpayOrderId: order.id,
        failureReason: null,
      },
    });

    await this.audit.record({
      action: 'payment.order_created',
      principalType: 'system',
      resourceType: 'payment',
      resourceId: payment.id,
      correlationId,
      metadata: {
        printJobId: payment.printJobId,
        razorpayOrderId: order.id,
        amountPaise: payment.amountPaise,
      },
    });

    return {
      alreadyPaid: false,
      printReady: false,
      payment: this.toCheckoutPublic(payment),
      razorpay_order_id: order.id,
      razorpay_key_id: this.razorpay.getKeyId(),
    };
  }

  async verifyPrintCheckoutPayment(
    token: string,
    input: {
      razorpay_order_id: string;
      razorpay_payment_id: string;
      razorpay_signature: string;
    },
    correlationId?: string,
  ) {
    const payment = await this.findCheckoutPayment(token);
    if (payment.razorpayOrderId && payment.razorpayOrderId !== input.razorpay_order_id) {
      throw new AppError('validation_error', 'Order does not match this checkout', 400);
    }

    const valid = verifyPaymentSignature({
      orderId: input.razorpay_order_id,
      paymentId: input.razorpay_payment_id,
      signature: input.razorpay_signature,
      keySecret: this.razorpay.getKeySecret(),
    });
    if (!valid) {
      throw new AppError('invalid_signature', 'Payment signature is invalid', 400);
    }

    const fulfilled = await this.payments.fulfillRazorpayPayment({
      razorpayOrderId: input.razorpay_order_id,
      razorpayPaymentId: input.razorpay_payment_id,
      razorpaySignature: input.razorpay_signature,
      allowExpiredFulfillment: false,
      correlationId,
    });

    return {
      alreadyPaid: fulfilled.alreadyPaid,
      printReady: true,
      payment: fulfilled.payment,
    };
  }

  private async findCheckoutPayment(token: string) {
    const payment = await this.db.payment.findUnique({
      where: { checkoutToken: token },
    });
    if (!payment || !payment.printJobId) {
      throw new AppError('not_found', 'Checkout not found', 404);
    }
    return payment;
  }

  private async expireIfNeeded<
    T extends {
      id: string;
      status: PaymentStatus;
      expiresAt: Date;
      razorpayQrCodeId?: string | null;
    },
  >(payment: T): Promise<T> {
    if (payment.status === PaymentStatus.PENDING && payment.expiresAt.getTime() < Date.now()) {
      if (payment.razorpayQrCodeId) {
        await this.razorpay.closeQrCode(payment.razorpayQrCodeId);
      }
      return (await this.db.payment.update({
        where: { id: payment.id },
        data: { status: PaymentStatus.EXPIRED },
      })) as unknown as T;
    }
    return payment;
  }

  private toCheckoutPublic(payment: {
    id: string;
    status: PaymentStatus;
    amountPaise: number;
    currency: string;
    expiresAt: Date;
    paidAt: Date | null;
    printJobId: string | null;
    checkoutToken: string | null;
  }) {
    return {
      id: payment.id,
      status: payment.status,
      amountPaise: payment.amountPaise,
      currency: payment.currency,
      expiresAt: payment.expiresAt.toISOString(),
      paidAt: payment.paidAt?.toISOString() ?? null,
      printJobId: payment.printJobId,
      title: 'Kundali color print',
    };
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
