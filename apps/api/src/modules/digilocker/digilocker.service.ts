import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import {
  DigiLockerSessionStatus,
  PaymentStatus,
  PrintColorMode,
  PrintJobSource,
} from '@prisma/client';
import type { AppConfig } from '../../config/index.js';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { DigiLockerClient } from '../../infrastructure/external/digilocker.types.js';
import type { SmsClient } from '../../infrastructure/external/sms.client.js';
import { startDigiLockerAuthorization } from '../../infrastructure/external/digilocker.client.js';
import { AppError } from '../../shared/errors.js';
import {
  generateNumericOtp,
  hashOtp,
  normalizePhone,
  sanitizeOtpDeliveryError,
} from '../../shared/otp.js';
import type { AuditService } from '../audit/audit.service.js';
import type { RazorpayClient } from '../payments/razorpay.client.js';
import { PlatformSettingsService } from '../platform_settings/platform_settings.service.js';
import { PrintQuotaService } from '../print_quota/print_quota.service.js';
import { assertPrintingAvailable } from '../printing/printing_pause.js';
import { countPdfPages } from '../printing/report_pdf.js';
import type { PrintingService } from '../printing/printing.service.js';
import { ServicesCatalogService } from '../services/services.service.js';
import type {
  DigiLockerColorMode,
  PrintDigiLockerInput,
  StartDigiLockerSessionInput,
} from './digilocker.schemas.js';
import {
  createDigiLockerPhoneProofToken,
  verifyDigiLockerPhoneProofToken,
} from './digilocker_phone_proof.js';

const SESSION_TTL_SECONDS = 600;
const digilockerPhoneOtpCooldownUntil = new Map<string, number>();

const digilockerQuotaDeviceSelect = {
  maxPagesPerSession: true,
  freePagesPerSession: true,
  extraPageChargeRupees: true,
  freeColorPagesPerSession: true,
  extraColorPageChargeRupees: true,
  freeDisabledFromLocal: true,
  freeDisabledToLocal: true,
  printingPausedReason: true,
} as const;

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

function toPrismaColorMode(mode: DigiLockerColorMode): PrintColorMode {
  return mode === 'color' ? PrintColorMode.color : PrintColorMode.bw;
}

export class DigiLockerService {
  private readonly quota: PrintQuotaService;
  private readonly settings: PlatformSettingsService;

  constructor(
    private readonly db: DbClient,
    private readonly digiLocker: DigiLockerClient,
    private readonly audit: AuditService,
    private readonly printing: PrintingService,
    private readonly services: ServicesCatalogService,
    private readonly config: AppConfig,
    private readonly razorpay: RazorpayClient,
    private readonly sms: SmsClient,
  ) {
    this.quota = new PrintQuotaService(db, audit);
    this.settings = new PlatformSettingsService(db, audit);
  }

  async startSession(deviceId: string, _input: StartDigiLockerSessionInput, correlationId?: string) {
    await assertPrintingAvailable(this.db, deviceId);
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

  async getPrintOptions(deviceId: string) {
    await this.services.assertEnabled(deviceId, 'digilocker_print');
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: {
        extraPageChargeRupees: true,
        extraColorPageChargeRupees: true,
      },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }
    return {
      bwChargeRupees: Math.max(0, device.extraPageChargeRupees ?? 0),
      colorChargeRupees: Math.max(0, device.extraColorPageChargeRupees ?? 0),
    };
  }

  async requestPhoneOtp(deviceId: string, phoneRaw: string, correlationId?: string) {
    await this.services.assertEnabled(deviceId, 'digilocker_print');
    let phone: string;
    try {
      phone = normalizePhone(phoneRaw);
    } catch {
      throw new AppError('invalid_phone', 'Enter a valid 10-digit mobile number', 400);
    }

    const authConfig = await this.settings.getCitizenAuthConfig();
    const cooldownMs = authConfig.requestCooldownSeconds * 1000;
    const until = digilockerPhoneOtpCooldownUntil.get(phone) ?? 0;
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

    digilockerPhoneOtpCooldownUntil.set(phone, Date.now() + cooldownMs);
    await this.audit.record({
      action: 'digilocker.phone_otp_requested',
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

  async verifyPhoneOtp(
    deviceId: string,
    phoneRaw: string,
    otp: string,
    colorMode: DigiLockerColorMode,
    correlationId?: string,
  ) {
    await this.services.assertEnabled(deviceId, 'digilocker_print');
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

    // Optimistic eligibility (page count unknown until download).
    const eligibility = await this.evaluateFreeEligibility(deviceId, phone, colorMode, 1);
    const phoneProofToken = createDigiLockerPhoneProofToken({
      deviceId,
      phone,
      jwtSecret: this.config.auth.jwtSecret,
    });

    await this.audit.record({
      action: 'digilocker.phone_otp_verified',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'device',
      resourceId: deviceId,
      correlationId,
      metadata: {
        phoneSuffix: phone.slice(-4),
        society: eligibility.society,
        freeEligible: eligibility.freeEligible,
        colorMode,
      },
    });

    return {
      phoneProofToken,
      society: eligibility.society,
      freeEligible: eligibility.freeEligible,
      remaining: eligibility.remaining,
      colorMode,
      message: eligibility.message,
    };
  }

  async printDocument(
    sessionId: string,
    deviceId: string,
    input: PrintDigiLockerInput,
    correlationId?: string,
  ) {
    await this.services.assertEnabled(deviceId, 'digilocker_print');
    await assertPrintingAvailable(this.db, deviceId);
    const session = await this.requireAuthorizedSession(sessionId, deviceId);

    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: digilockerQuotaDeviceSelect,
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const colorMode = input.colorMode;
    const chargePerPageRupees = Math.max(
      0,
      colorMode === 'color'
        ? (device.extraColorPageChargeRupees ?? 0)
        : (device.extraPageChargeRupees ?? 0),
    );

    // documentId is the DigiLocker URI (or synthetic eaadhaar:xml). Do not re-list
    // issued/uploaded here — that triggers DigiLocker rate limits (429).
    const documentUri = input.documentId;
    const title =
      input.title?.trim() ||
      (documentUri === 'eaadhaar:xml' ? 'e-Aadhaar' : 'DigiLocker document');

    const file = await this.digiLocker.downloadFile(session.accessToken!, documentUri);
    const pageCount = Math.max(1, await countPdfPages(file.bytes));

    let freePhone: string | null = null;
    let freePeriodKey: string | null = null;
    if (chargePerPageRupees > 0 && input.phoneProofToken) {
      const proof = verifyDigiLockerPhoneProofToken({
        token: input.phoneProofToken,
        deviceId,
        jwtSecret: this.config.auth.jwtSecret,
      });
      if (proof) {
        const eligibility = await this.evaluateFreeEligibility(
          deviceId,
          proof.phone,
          colorMode,
          pageCount,
        );
        if (eligibility.freeEligible) {
          freePhone = proof.phone;
          freePeriodKey = eligibility.periodKey;
        }
      }
    }

    if (
      chargePerPageRupees > 0 &&
      !freePhone &&
      (!this.config.razorpay.keyId || !this.config.razorpay.keySecret)
    ) {
      throw new AppError(
        'payments_not_configured',
        'Paid printing is not available on this kiosk right now',
        503,
      );
    }

    const printColorMode = toPrismaColorMode(colorMode);
    const freePagesGranted = freePhone ? pageCount : 0;
    const job = await this.printing.createJob(
      {
        source: PrintJobSource.digilocker_print,
        title,
        pageCount,
        pagesExpected: pageCount,
        freePagesGranted,
        printColorMode,
        deviceId,
        payloadUrl: `/v1/print-jobs/pending/content`,
        digiLockerSessionId: session.id,
        idempotencyKey:
          input.idempotencyKey ??
          `dl-print-${session.id}-${documentUri}-${colorMode}`.slice(0, 100),
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
      metadata: {
        documentId: documentUri,
        sessionId,
        colorMode,
        pageCount,
        freePages: freePagesGranted,
      },
    });

    if (chargePerPageRupees <= 0 || freePhone) {
      if (freePhone && freePeriodKey) {
        await this.quota.reserveFreePages({
          phone: freePhone,
          mode: colorMode,
          pages: pageCount,
          periodKey: freePeriodKey,
          printJobId: job.id,
        });
      }
      return {
        ...updated,
        paymentRequired: false,
        amountPaise: 0,
        currency: 'INR',
        paymentId: null,
        checkoutToken: null,
        checkoutUrl: null,
        qrImageUrl: null,
        freePages: freePagesGranted,
      };
    }

    const amountPaise = pageCount * chargePerPageRupees * 100;
    const nowMs = Date.now();
    const windowMs = this.config.payments.windowMinutes * 60_000;
    const closeByMs = Math.min(
      Math.max(nowMs + windowMs, nowMs + 2 * 60_000),
      nowMs + 2 * 60 * 60_000,
    );
    const closeByUnix = Math.floor(closeByMs / 1000);
    const modeLabel = colorMode === 'color' ? 'color' : 'B&W';

    const qr = await this.razorpay.createUpiQrCode({
      amountPaise,
      description: `DigiLocker ${modeLabel} print - ${title}`.slice(0, 512),
      name: `DigiLocker ${modeLabel} print`.slice(0, 45),
      closeByUnix,
      notes: {
        print_job_id: job.id,
        device_id: deviceId,
        kind: 'digilocker_print',
        color_mode: colorMode,
      },
    });

    const expiresAt = new Date((qr.closeBy || closeByUnix) * 1000);

    const payment = await this.db.payment.create({
      data: {
        printJobId: job.id,
        status: PaymentStatus.PENDING,
        pageCount,
        freePages: 0,
        extraPages: pageCount,
        printColorMode,
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
        kind: 'digilocker_print',
      },
    });

    return {
      ...updated,
      paymentRequired: true,
      amountPaise,
      currency: 'INR',
      paymentId: payment.id,
      checkoutToken: null,
      checkoutUrl: null,
      qrImageUrl: qr.imageUrl,
      freePages: 0,
    };
  }

  async getPrintJobPayment(deviceId: string, jobId: string) {
    const job = await this.db.printJob.findUnique({
      where: { id: jobId },
      include: { payment: true },
    });
    if (
      !job ||
      job.source !== PrintJobSource.digilocker_print ||
      (job.deviceId && job.deviceId !== deviceId)
    ) {
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
        qrImageUrl: null,
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
      qrImageUrl: payment.qrImageUrl ?? null,
    };
  }

  private async evaluateFreeEligibility(
    deviceId: string,
    phone: string,
    mode: DigiLockerColorMode,
    pageCount: number,
  ) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: digilockerQuotaDeviceSelect,
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const remaining = await this.quota.getRemaining(phone, mode);
    const modeLabel = mode === 'color' ? 'color' : 'B&W';
    if (!remaining.society) {
      return {
        society: false,
        freeEligible: false,
        remaining: remaining.remaining,
        periodKey: remaining.periodKey,
        message: 'This number isn’t on the society free list. Continue with payment.',
      };
    }

    const effective = await this.quota.computeEffectiveFree({
      phone,
      device,
      mode,
      pageCount,
    });

    if (effective.freeDisabledNow) {
      return {
        society: true,
        freeEligible: false,
        remaining: effective.remainingBefore,
        periodKey: effective.periodKey,
        message: 'Free prints are paused on this kiosk right now. Continue with payment.',
      };
    }
    if (effective.freePages < pageCount) {
      return {
        society: true,
        freeEligible: false,
        remaining: effective.remainingBefore,
        periodKey: effective.periodKey,
        message:
          effective.remainingBefore < 1
            ? `No free ${modeLabel} pages left. Continue with payment.`
            : `Not enough free ${modeLabel} pages for this document. Continue with payment.`,
      };
    }

    return {
      society: true,
      freeEligible: true,
      remaining: effective.remainingBefore,
      periodKey: effective.periodKey,
      message: null as string | null,
    };
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
    if (
      checkExpiry &&
      session.expiresAt.getTime() < Date.now() &&
      session.status === DigiLockerSessionStatus.pending
    ) {
      await this.db.digiLockerSession.update({
        where: { id: sessionId },
        data: { status: DigiLockerSessionStatus.expired },
      });
      throw new AppError('session_expired', 'DigiLocker session expired', 400);
    }
    return session;
  }
}
