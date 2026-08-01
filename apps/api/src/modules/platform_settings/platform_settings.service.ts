import type { Prisma } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import {
  CITIZEN_AUTH_CONFIG_KEY,
  DEFAULT_CITIZEN_AUTH_CONFIG,
  DEFAULT_OTP_PRINT_CONFIG,
  DEFAULT_SMS_CONFIG,
  OTP_PRINT_CONFIG_KEY,
  SMS_CONFIG_KEY,
  type CitizenAuthConfig,
  type OtpPrintConfig,
  type SmsConfig,
} from './platform_settings.defaults.js';
import {
  citizenAuthConfigSchema,
  otpPrintConfigSchema,
  smsConfigSchema,
  type UpdatePlatformSettingInput,
} from './platform_settings.schemas.js';

function asObject(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function normalizeSmsConfig(raw: unknown): SmsConfig {
  const obj = asObject(raw);
  const flowId = String(obj.flow_id || obj.template_id || obj.sms_templateid || '').trim();
  return {
    provider: 'msg91',
    enabled: obj.enabled !== false,
    auth_key: String(obj.auth_key || obj.sms_apikey || ''),
    sender_id: String(obj.sender_id || obj.sms_sendername || ''),
    flow_id: flowId,
    otp_var_name: String(obj.otp_var_name || 'OTP').trim() || 'OTP',
    message_template: String(obj.message_template || obj.sms_message || DEFAULT_SMS_CONFIG.message_template),
  };
}

function maskSmsConfig(config: SmsConfig): SmsConfig & { auth_key_configured: boolean } {
  const key = config.auth_key;
  const masked =
    key.length <= 4 ? (key ? '****' : '') : `${'*'.repeat(Math.max(0, key.length - 4))}${key.slice(-4)}`;
  return {
    ...config,
    auth_key: masked,
    auth_key_configured: Boolean(key),
  };
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

  async getRaw(settingKey: string) {
    return this.db.platformSetting.findUnique({ where: { settingKey } });
  }

  async getSmsConfig(): Promise<SmsConfig> {
    const row = await this.getRaw(SMS_CONFIG_KEY);
    if (!row || !row.isActive) {
      return { ...DEFAULT_SMS_CONFIG, enabled: false };
    }
    return normalizeSmsConfig(row.settingValue);
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
    if (settingKey === SMS_CONFIG_KEY) {
      const normalized = normalizeSmsConfig(raw);
      // Preserve existing auth_key when admin sends masked/empty update with configured flag pattern
      const parsed = smsConfigSchema.safeParse(normalized);
      if (!parsed.success) {
        throw new AppError('validation_error', parsed.error.issues[0]?.message ?? 'Invalid sms_config', 400);
      }
      return parsed.data;
    }
    if (settingKey === OTP_PRINT_CONFIG_KEY) {
      const parsed = otpPrintConfigSchema.safeParse(raw);
      if (!parsed.success) {
        throw new AppError(
          'validation_error',
          parsed.error.issues[0]?.message ?? 'Invalid otp_print_config',
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
    let value: unknown = settingValue;
    if (settingKey === SMS_CONFIG_KEY) {
      value = maskSmsConfig(normalizeSmsConfig(settingValue));
    }
    return {
      id: row.id,
      settingKey,
      settingValue: value,
      description: row.description,
      isActive: row.isActive,
      updatedAt: row.updatedAt.toISOString(),
    };
  }

  /** Merge blank/masked auth_key with existing on update. */
  async prepareSmsUpdate(raw: unknown): Promise<unknown> {
    const incoming = normalizeSmsConfig(raw);
    const existing = await this.getSmsConfig();
    const looksMasked =
      !incoming.auth_key ||
      /^\*+\w{0,4}$/.test(incoming.auth_key) ||
      incoming.auth_key.includes('*');
    return {
      ...incoming,
      auth_key: looksMasked ? existing.auth_key : incoming.auth_key,
    };
  }
}
