import { PaymentStatus, PrintColorMode, PrintJobSource } from '@prisma/client';
import type { AppConfig } from '../../config/index.js';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { SmsClient } from '../../infrastructure/external/sms.client.js';
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
import { createPrintJobWithPdf } from '../printing/create_print_job_with_pdf.js';
import { assertPrintingAvailable } from '../printing/printing_pause.js';
import { countPdfPages } from '../printing/report_pdf.js';
import { PrintingService } from '../printing/printing.service.js';
import { buildHealthReportPdf } from './well_being_report_pdf.js';
import type { WellBeingColorMode, WellBeingPrintBody } from './well_being.schemas.js';
import {
  createWellBeingPhoneProofToken,
  verifyWellBeingPhoneProofToken,
} from './well_being_phone_proof.js';

const wellBeingPhoneOtpCooldownUntil = new Map<string, number>();

const wellBeingQuotaDeviceSelect = {
  maxPagesPerSession: true,
  freePagesPerSession: true,
  extraPageChargeRupees: true,
  freeColorPagesPerSession: true,
  extraColorPageChargeRupees: true,
  freeDisabledFromLocal: true,
  freeDisabledToLocal: true,
  printingPausedReason: true,
} as const;

function toPrismaColorMode(mode: WellBeingColorMode): PrintColorMode {
  return mode === 'color' ? PrintColorMode.color : PrintColorMode.bw;
}

export class WellBeingService {
  private readonly printing: PrintingService;
  private readonly quota: PrintQuotaService;
  private readonly settings: PlatformSettingsService;

  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
    private readonly config: AppConfig,
    private readonly razorpay: RazorpayClient,
    private readonly sms: SmsClient,
  ) {
    this.printing = new PrintingService(db, audit);
    this.quota = new PrintQuotaService(db, audit);
    this.settings = new PlatformSettingsService(db, audit);
  }

  async getPrintOptions(deviceId: string) {
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
    let phone: string;
    try {
      phone = normalizePhone(phoneRaw);
    } catch {
      throw new AppError('invalid_phone', 'Enter a valid 10-digit mobile number', 400);
    }

    const authConfig = await this.settings.getCitizenAuthConfig();
    const cooldownMs = authConfig.requestCooldownSeconds * 1000;
    const until = wellBeingPhoneOtpCooldownUntil.get(phone) ?? 0;
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

    wellBeingPhoneOtpCooldownUntil.set(phone, Date.now() + cooldownMs);
    await this.audit.record({
      action: 'well_being.phone_otp_requested',
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
    colorMode: WellBeingColorMode,
    correlationId?: string,
  ) {
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

    const eligibility = await this.evaluateFreeEligibility(deviceId, phone, colorMode, 1);
    const phoneProofToken = createWellBeingPhoneProofToken({
      deviceId,
      phone,
      jwtSecret: this.config.auth.jwtSecret,
    });

    await this.audit.record({
      action: 'well_being.phone_otp_verified',
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

  async printReport(deviceId: string, input: WellBeingPrintBody, correlationId?: string) {
    await assertPrintingAvailable(this.db, deviceId);

    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: wellBeingQuotaDeviceSelect,
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

    const bytes = await buildHealthReportPdf(input);
    const pageCount = Math.max(1, await countPdfPages(bytes));
    const title =
      input.mode === 'oxi' ? 'Health Report — Pulse oximetry' : 'Health Report — Temperature';
    const printColorMode = toPrismaColorMode(colorMode);

    let freePhone: string | null = null;
    let freePeriodKey: string | null = null;
    if (chargePerPageRupees > 0 && input.phoneProofToken) {
      const proof = verifyWellBeingPhoneProofToken({
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

    const freePagesGranted = freePhone ? pageCount : 0;
    const job = await createPrintJobWithPdf(
      this.printing,
      {
        source: PrintJobSource.well_being_print,
        title,
        deviceId,
        bytes,
        folder: 'well_being',
        printColorMode,
        freePagesGranted,
        idempotencyKey:
          input.idempotencyKey ??
          `wb-${input.mode}-${colorMode}-${deviceId}-${input.measuredAt ?? Date.now()}`.slice(
            0,
            100,
          ),
      },
      'device',
      correlationId,
    );

    await this.audit.record({
      action: 'well_being.print_requested',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'print_job',
      resourceId: job.id,
      correlationId,
      metadata: {
        mode: input.mode,
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
        ...job,
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
      description: `Well Being ${modeLabel} print - ${title}`.slice(0, 512),
      name: `Well Being ${modeLabel} print`.slice(0, 45),
      closeByUnix,
      notes: {
        print_job_id: job.id,
        device_id: deviceId,
        kind: 'well_being_print',
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
        kind: 'well_being_print',
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
      job.source !== PrintJobSource.well_being_print ||
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
    mode: WellBeingColorMode,
    pageCount: number,
  ) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: wellBeingQuotaDeviceSelect,
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
            : `Not enough free ${modeLabel} pages for this report. Continue with payment.`,
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
}
