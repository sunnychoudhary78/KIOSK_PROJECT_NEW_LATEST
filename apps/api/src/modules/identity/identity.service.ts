import bcrypt from 'bcryptjs';
import { DeviceStatus, UserRole } from '@prisma/client';
import type { AppConfig } from '../../config/index.js';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import type { SmsClient } from '../../infrastructure/external/sms.client.js';
import { AppError } from '../../shared/errors.js';
import { signAccessToken } from '../../shared/auth.js';
import {
  generateNumericOtp,
  hashOtp,
  normalizePhone,
  sanitizeOtpDeliveryError,
} from '../../shared/otp.js';
import type { AuditService } from '../audit/audit.service.js';
import { PlatformSettingsService } from '../platform_settings/platform_settings.service.js';
import type {
  AdminLoginInput,
  CitizenOtpRequestInput,
  CitizenOtpVerifyInput,
  DeviceTokenInput,
} from './identity.schemas.js';

const requestCooldownUntil = new Map<string, number>();

export class IdentityService {
  private readonly settings: PlatformSettingsService;

  constructor(
    private readonly db: DbClient,
    private readonly config: AppConfig,
    private readonly audit: AuditService,
    private readonly sms: SmsClient,
  ) {
    this.settings = new PlatformSettingsService(db, audit);
  }

  async citizenOtpRequest(input: CitizenOtpRequestInput, correlationId?: string) {
    let phone: string;
    try {
      phone = normalizePhone(input.phone);
    } catch {
      throw new AppError('invalid_phone', 'Enter a valid 10-digit mobile number', 400);
    }

    const authConfig = await this.settings.getCitizenAuthConfig();
    const cooldownMs = authConfig.requestCooldownSeconds * 1000;
    const until = requestCooldownUntil.get(phone) ?? 0;
    if (Date.now() < until) {
      throw new AppError('otp_cooldown', 'Please wait before requesting another OTP', 429);
    }

    const code = generateNumericOtp(authConfig.otpLength);
    const expiresAt = new Date(Date.now() + authConfig.ttlSeconds * 1000);

    await this.db.phoneOtpSession.upsert({
      where: { phone },
      create: {
        phone,
        codeHash: hashOtp(code),
        expiresAt,
        attemptCount: 0,
      },
      update: {
        codeHash: hashOtp(code),
        expiresAt,
        attemptCount: 0,
      },
    });

    try {
      await this.sms.sendOtp(phone, code, authConfig.ttlSeconds);
    } catch (error) {
      await this.db.phoneOtpSession.delete({ where: { phone } }).catch(() => undefined);
      throw new AppError('sms_failed', sanitizeOtpDeliveryError(error), 502);
    }

    requestCooldownUntil.set(phone, Date.now() + cooldownMs);

    await this.audit.record({
      action: 'auth.citizen_otp_requested',
      principalType: 'citizen',
      principalId: phone,
      correlationId,
    });

    const includeDevOtp =
      this.config.env === 'local' || this.config.env === 'test' || this.config.env === 'dev';

    return {
      message: 'OTP sent successfully',
      expiresAt: expiresAt.toISOString(),
      ...(includeDevOtp ? { devOtp: code } : {}),
    };
  }

  async citizenOtpVerify(input: CitizenOtpVerifyInput, correlationId?: string) {
    let phone: string;
    try {
      phone = normalizePhone(input.phone);
    } catch {
      throw new AppError('invalid_phone', 'Enter a valid 10-digit mobile number', 400);
    }

    const authConfig = await this.settings.getCitizenAuthConfig();
    const session = await this.db.phoneOtpSession.findUnique({ where: { phone } });
    if (!session) {
      throw new AppError('otp_invalid', 'Invalid or expired OTP', 400);
    }

    if (session.attemptCount >= authConfig.maxVerifyAttempts) {
      await this.db.phoneOtpSession.delete({ where: { phone } }).catch(() => undefined);
      throw new AppError('otp_locked', 'Too many invalid attempts. Request a new OTP.', 400);
    }

    if (session.expiresAt.getTime() < Date.now()) {
      await this.db.phoneOtpSession.delete({ where: { phone } }).catch(() => undefined);
      throw new AppError('otp_expired', 'OTP has expired', 400);
    }

    if (session.codeHash !== hashOtp(input.otp)) {
      await this.db.phoneOtpSession.update({
        where: { phone },
        data: { attemptCount: { increment: 1 } },
      });
      throw new AppError('otp_invalid', 'Invalid or expired OTP', 400);
    }

    await this.db.phoneOtpSession.delete({ where: { phone } });

    let user = await this.db.user.findUnique({ where: { phone } });
    if (!user) {
      user = await this.db.user.create({
        data: {
          phone,
          displayName: `Citizen ${phone.slice(-4)}`,
          role: UserRole.citizen,
          passwordHash: null,
        },
      });
    } else if (user.role !== UserRole.citizen || !user.isActive) {
      throw new AppError('invalid_credentials', 'Account is not allowed to sign in', 401);
    }

    const token = signAccessToken(this.config, {
      type: 'citizen',
      id: user.id,
      role: user.role,
      tenantId: user.tenantId ?? undefined,
    });

    await this.audit.record({
      action: 'auth.citizen_login',
      principalType: 'citizen',
      principalId: user.id,
      correlationId,
    });

    return {
      accessToken: token.accessToken,
      tokenType: 'Bearer' as const,
      expiresIn: token.expiresIn,
      principalType: 'citizen' as const,
    };
  }

  async adminLogin(input: AdminLoginInput, correlationId?: string) {
    const user = await this.db.user.findUnique({ where: { email: input.email } });
    const adminRoles: UserRole[] = [UserRole.admin, UserRole.operator, UserRole.viewer];
    if (!user || !adminRoles.includes(user.role) || !user.isActive || !user.passwordHash) {
      throw new AppError('invalid_credentials', 'Invalid email or password', 401);
    }

    const ok = await bcrypt.compare(input.password, user.passwordHash);
    if (!ok) {
      throw new AppError('invalid_credentials', 'Invalid email or password', 401);
    }

    const token = signAccessToken(this.config, {
      type: 'admin',
      id: user.id,
      role: user.role,
      tenantId: user.tenantId ?? undefined,
    });

    await this.audit.record({
      action: 'auth.admin_login',
      principalType: 'admin',
      principalId: user.id,
      correlationId,
    });

    return {
      accessToken: token.accessToken,
      tokenType: 'Bearer' as const,
      expiresIn: token.expiresIn,
      principalType: 'admin' as const,
    };
  }

  async deviceToken(input: DeviceTokenInput, correlationId?: string) {
    const device = await this.db.device.findUnique({ where: { deviceKey: input.deviceKey } });
    if (!device) {
      throw new AppError('invalid_credentials', 'Invalid device credentials', 401);
    }
    if (device.status === DeviceStatus.inactive) {
      throw new AppError('device_inactive', 'This kiosk has been stopped', 403);
    }

    const ok = await bcrypt.compare(input.deviceSecret, device.deviceSecretHash);
    if (!ok) {
      throw new AppError('invalid_credentials', 'Invalid device credentials', 401);
    }

    if (device.status === DeviceStatus.provisioning) {
      await this.db.device.update({
        where: { id: device.id },
        data: { status: DeviceStatus.active },
      });
    }

    const token = signAccessToken(this.config, {
      type: 'device',
      id: device.id,
      deviceId: device.id,
      tenantId: device.tenantId,
    });

    await this.audit.record({
      action: 'auth.device_token',
      principalType: 'device',
      principalId: device.id,
      resourceType: 'device',
      resourceId: device.id,
      correlationId,
    });

    return {
      accessToken: token.accessToken,
      tokenType: 'Bearer' as const,
      expiresIn: token.expiresIn,
      principalType: 'device' as const,
      deviceId: device.id,
      deviceName: device.name,
      surveillanceEnabled: device.surveillanceEnabled,
    };
  }
}
