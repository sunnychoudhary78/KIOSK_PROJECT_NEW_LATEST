import type { Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import {
  CITIZEN_AUTH_CONFIG_KEY,
  DEFAULT_CITIZEN_AUTH_CONFIG,
  DEFAULT_OTP_PRINT_CONFIG,
  DEFAULT_QUICK_PRINT_CONFIG,
  OTP_PRINT_CONFIG_KEY,
  QUICK_PRINT_CONFIG_KEY,
  SMS_CONFIG_KEY,
  type CitizenAuthConfig,
  type OtpPrintConfig,
  type QuickPrintConfig,
} from './platform_settings.defaults.js';
import {
  citizenAuthConfigSchema,
  otpPrintConfigSchema,
  quickPrintConfigSchema,
  type UpdatePlatformSettingInput,
} from './platform_settings.schemas.js';

function asObject(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

export class PlatformSettingsService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {}

  async list() {
    const rows = await this.db.platformSetting.findMany({ orderBy: { settingKey: 'asc' } });
    return rows.map((row) => this.toPublic(row.settingKey, row.settingValue, row));
  }

  /** Operational settings only (SMS credentials live in env). */
  async listOperational() {
    const items = await this.list();
    return items.filter((item) => item.settingKey !== SMS_CONFIG_KEY);
  }

  async getRaw(settingKey: string) {
    return this.db.platformSetting.findUnique({ where: { settingKey } });
  }

  async getOtpPrintConfig(): Promise<OtpPrintConfig> {
    const row = await this.getRaw(OTP_PRINT_CONFIG_KEY);
    if (!row) {
      return { ...DEFAULT_OTP_PRINT_CONFIG };
    }
    const parsed = otpPrintConfigSchema.safeParse({
      ...DEFAULT_OTP_PRINT_CONFIG,
      ...asObject(row.settingValue),
    });
    return parsed.success ? parsed.data : { ...DEFAULT_OTP_PRINT_CONFIG };
  }

  async getQuickPrintConfig(): Promise<QuickPrintConfig> {
    const row = await this.getRaw(QUICK_PRINT_CONFIG_KEY);
    if (!row) {
      return { ...DEFAULT_QUICK_PRINT_CONFIG };
    }
    const parsed = quickPrintConfigSchema.safeParse({
      ...DEFAULT_QUICK_PRINT_CONFIG,
      ...asObject(row.settingValue),
    });
    return parsed.success ? parsed.data : { ...DEFAULT_QUICK_PRINT_CONFIG };
  }

  async getCitizenAuthConfig(): Promise<CitizenAuthConfig> {
    const row = await this.getRaw(CITIZEN_AUTH_CONFIG_KEY);
    if (!row) {
      return { ...DEFAULT_CITIZEN_AUTH_CONFIG };
    }
    const parsed = citizenAuthConfigSchema.safeParse({
      ...DEFAULT_CITIZEN_AUTH_CONFIG,
      ...asObject(row.settingValue),
    });
    return parsed.success ? parsed.data : { ...DEFAULT_CITIZEN_AUTH_CONFIG };
  }

  async update(
    settingKey: string,
    input: UpdatePlatformSettingInput,
    adminId: string,
    correlationId?: string,
  ) {
    if (settingKey === SMS_CONFIG_KEY) {
      throw new AppError(
        'sms_config_deprecated',
        'SMS credentials are configured via environment variables (SKP_MSG91_*), not platform settings',
        400,
      );
    }
    const value = this.validateValue(settingKey, input.settingValue);
    const existing = await this.getRaw(settingKey);

    const jsonValue = value as Prisma.InputJsonValue;
    const row = existing
      ? await this.db.platformSetting.update({
          where: { settingKey },
          data: {
            settingValue: jsonValue,
            description: input.description ?? existing.description,
            isActive: input.isActive ?? existing.isActive,
          },
        })
      : await this.db.platformSetting.create({
          data: {
            settingKey,
            settingValue: jsonValue,
            description: input.description,
            isActive: input.isActive ?? true,
          },
        });

    await this.audit.record({
      action: 'platform_setting.updated',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'platform_setting',
      resourceId: row.id,
      correlationId,
      metadata: { settingKey },
    });

    return this.toPublic(row.settingKey, row.settingValue, row);
  }

  private validateValue(settingKey: string, raw: unknown): unknown {
    if (settingKey === OTP_PRINT_CONFIG_KEY) {
      const parsed = otpPrintConfigSchema.safeParse({
        ...DEFAULT_OTP_PRINT_CONFIG,
        ...asObject(raw),
      });
      if (!parsed.success) {
        throw new AppError(
          'validation_error',
          parsed.error.issues[0]?.message ?? 'Invalid otp_print_config',
          400,
        );
      }
      return parsed.data;
    }
    if (settingKey === QUICK_PRINT_CONFIG_KEY) {
      const parsed = quickPrintConfigSchema.safeParse({
        ...DEFAULT_QUICK_PRINT_CONFIG,
        ...asObject(raw),
      });
      if (!parsed.success) {
        throw new AppError(
          'validation_error',
          parsed.error.issues[0]?.message ?? 'Invalid quick_print_config',
          400,
        );
      }
      return parsed.data;
    }
    if (settingKey === CITIZEN_AUTH_CONFIG_KEY) {
      const parsed = citizenAuthConfigSchema.safeParse(raw);
      if (!parsed.success) {
        throw new AppError(
          'validation_error',
          parsed.error.issues[0]?.message ?? 'Invalid citizen_auth_config',
          400,
        );
      }
      return parsed.data;
    }
    throw new AppError('unknown_setting', `Unknown setting key: ${settingKey}`, 404);
  }

  private toPublic(
    settingKey: string,
    settingValue: unknown,
    row: { id: string; description: string | null; isActive: boolean; updatedAt: Date },
  ) {
    return {
      id: row.id,
      settingKey,
      settingValue,
      description: row.description,
      isActive: row.isActive,
      updatedAt: row.updatedAt.toISOString(),
    };
  }
}
