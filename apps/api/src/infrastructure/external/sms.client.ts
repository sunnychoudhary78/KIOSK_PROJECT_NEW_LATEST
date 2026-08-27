import type { Logger } from '../logging/logger.js';
import type { AppConfig } from '../../config/index.js';
import { formatOtpExpiryLabel, phoneDigits10 } from '../../shared/otp.js';

export const MSG91_FLOW_URL = 'https://control.msg91.com/api/v5/flow';
export const MSG91_PROVIDER = 'msg91';

/** Default MSG91 Flow shortcodes (override via SKP_MSG91_OTP_VAR / SKP_MSG91_EXPIRY_VAR). */
export const MSG91_OTP_VAR_DEFAULT = 'var1';
export const MSG91_EXPIRY_VAR_DEFAULT = 'var2';

/** @deprecated Use MSG91_OTP_VAR_DEFAULT — kept for existing imports. */
export const MSG91_OTP_VAR = MSG91_OTP_VAR_DEFAULT;
/** @deprecated Use MSG91_EXPIRY_VAR_DEFAULT — kept for existing imports. */
export const MSG91_EXPIRY_VAR = MSG91_EXPIRY_VAR_DEFAULT;

/** Reference copy matching the DLT Flow template (MSG91 owns the live text). */
export const MSG91_TEMPLATE_REFERENCE =
  'Your OTP for IMMORTAL is ##var1## Valid for ##var2##. Do not share this code.';

export type Msg91EnvConfig = {
  provider: 'noop' | 'msg91';
  authKey: string;
  senderId: string;
  flowId: string;
  /** Flow recipient field name for OTP (e.g. var1). */
  otpVar: string;
  /** Flow recipient field name for expiry (e.g. var2). */
  expiryVar: string;
};

export interface SmsClient {
  sendOtp(phone: string, otp: string, ttlSeconds: number): Promise<void>;
}

export function isMsg91Configured(msg91: Msg91EnvConfig): boolean {
  return (
    msg91.provider === MSG91_PROVIDER &&
    Boolean(msg91.authKey.trim() && msg91.senderId.trim() && msg91.flowId.trim())
  );
}

export function msg91ConfigFromApp(config: AppConfig): Msg91EnvConfig {
  return {
    provider: config.smsProvider,
    authKey: config.msg91.authKey,
    senderId: config.msg91.senderId,
    flowId: config.msg91.flowId,
    otpVar: config.msg91.otpVar,
    expiryVar: config.msg91.expiryVar,
  };
}

export function createNoopSmsClient(logger?: Logger): SmsClient {
  return {
    async sendOtp(phone, otp, ttlSeconds): Promise<void> {
      logger?.info(
        { phone, otpPreview: otp, expiryLabel: formatOtpExpiryLabel(ttlSeconds) },
        '[OTP SMS] noop delivery',
      );
    },
  };
}

type FetchLike = typeof fetch;

export function createMsg91FlowSmsClient(options: {
  msg91: Msg91EnvConfig;
  logger: Logger;
  fetchImpl?: FetchLike;
  allowNoopWhenDisabled?: boolean;
}): SmsClient {
  const fetchImpl = options.fetchImpl ?? fetch;

  return {
    async sendOtp(phone: string, otp: string, ttlSeconds: number): Promise<void> {
      if (!isMsg91Configured(options.msg91)) {
        if (options.allowNoopWhenDisabled) {
          options.logger.info({ phone }, '[OTP SMS] MSG91 not configured; noop delivery');
          return;
        }
        throw new Error('Failed to send OTP SMS: MSG91 configuration is incomplete');
      }

      validateMsg91EnvConfig(options.msg91);
      const mobileIntl = `91${phoneDigits10(phone)}`;
      const expiryLabel = formatOtpExpiryLabel(ttlSeconds);
      const otpVar = options.msg91.otpVar.trim() || MSG91_OTP_VAR_DEFAULT;
      const expiryVar = options.msg91.expiryVar.trim() || MSG91_EXPIRY_VAR_DEFAULT;
      const body = {
        flow_id: options.msg91.flowId.trim(),
        sender: options.msg91.senderId.trim(),
        recipients: [
          {
            mobiles: mobileIntl,
            [otpVar]: String(otp),
            [expiryVar]: expiryLabel,
          },
        ],
      };

      options.logger.info(
        {
          url: MSG91_FLOW_URL,
          flow_id: body.flow_id,
          sender: body.sender,
          mobiles: mobileIntl,
          otpVar,
          expiryVar,
          expiryLabel,
          recipientKeys: Object.keys(body.recipients[0]!),
        },
        '[MSG91 REQUEST]',
      );

      const response = await fetchImpl(MSG91_FLOW_URL, {
        method: 'POST',
        headers: {
          authkey: options.msg91.authKey.trim(),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(15_000),
      });

      let data: unknown;
      try {
        data = await response.json();
      } catch {
        data = null;
      }

      const type =
        data && typeof data === 'object' && 'type' in data
          ? String((data as { type?: unknown }).type ?? '')
          : null;
      const requestId =
        data && typeof data === 'object' && data !== null && 'message' in data
          ? String((data as { message?: unknown }).message ?? '')
          : null;

      options.logger.info(
        {
          status: response.status,
          type,
          requestId,
          body: data,
          hint:
            'If type=success but SMS missing, check MSG91 Logs/Delivery for this requestId (DLT scrubbing).',
        },
        '[MSG91 RESPONSE]',
      );

      if (!response.ok || (type && type !== 'success')) {
        const message =
          data && typeof data === 'object' && data !== null
            ? String(
                (data as { message?: unknown; error?: unknown }).message ||
                  (data as { error?: unknown }).error ||
                  JSON.stringify(data),
              )
            : 'Unknown MSG91 error';
        throw new Error(`MSG91 SMS failed: ${message}`);
      }
    },
  };
}

export function validateMsg91EnvConfig(config: Msg91EnvConfig): void {
  if (config.provider !== MSG91_PROVIDER) {
    throw new Error(`Failed to send OTP SMS: unsupported SMS provider "${config.provider}"`);
  }
  const missing: string[] = [];
  if (!config.authKey.trim()) missing.push('SKP_MSG91_AUTH_KEY');
  if (!config.senderId.trim()) missing.push('SKP_MSG91_SENDER_ID');
  if (!config.flowId.trim()) missing.push('SKP_MSG91_FLOW_ID');
  if (missing.length) {
    throw new Error(
      `Failed to send OTP SMS: MSG91 configuration is incomplete (missing: ${missing.join(', ')})`,
    );
  }
}
