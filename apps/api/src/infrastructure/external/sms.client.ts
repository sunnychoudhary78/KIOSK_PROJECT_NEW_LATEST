import type { Logger } from '../logging/logger.js';
import type { PlatformSettingsService } from '../../modules/platform_settings/platform_settings.service.js';
import type { SmsConfig } from '../../modules/platform_settings/platform_settings.defaults.js';
import { phoneDigits10 } from '../../shared/otp.js';

export const MSG91_FLOW_URL = 'https://control.msg91.com/api/v5/flow';
export const MSG91_PROVIDER = 'msg91';

export interface SmsClient {
  sendOtp(phone: string, otp: string): Promise<void>;
}

export function createNoopSmsClient(logger?: Logger): SmsClient {
  return {
    async sendOtp(phone, otp): Promise<void> {
      logger?.info({ phone, otpPreview: otp }, '[OTP SMS] noop delivery');
    },
  };
}

type FetchLike = typeof fetch;

export function createMsg91FlowSmsClient(options: {
  settings: PlatformSettingsService;
  logger: Logger;
  fetchImpl?: FetchLike;
  allowNoopWhenDisabled?: boolean;
}): SmsClient {
  const fetchImpl = options.fetchImpl ?? fetch;

  return {
    async sendOtp(phone: string, otp: string): Promise<void> {
      const config = await options.settings.getSmsConfig();
      if (!config.enabled) {
        if (options.allowNoopWhenDisabled) {
          options.logger.info({ phone }, '[OTP SMS] SMS disabled; noop delivery');
          return;
        }
        throw new Error('Failed to send OTP SMS: SMS configuration is incomplete');
      }

      validateSmsConfig(config);
      const mobileIntl = `91${phoneDigits10(phone)}`;
      const varName = config.otp_var_name.trim();
      const body = {
        flow_id: config.flow_id.trim(),
        sender: config.sender_id.trim(),
        recipients: [
          {
            mobiles: mobileIntl,
            [varName]: String(otp),
          },
        ],
      };

      options.logger.info(
        {
          url: MSG91_FLOW_URL,
          flow_id: body.flow_id,
          sender: body.sender,
          mobiles: mobileIntl,
        },
        '[MSG91 REQUEST]',
      );

      const response = await fetchImpl(MSG91_FLOW_URL, {
        method: 'POST',
        headers: {
          authkey: config.auth_key.trim(),
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

      options.logger.info(
        { status: response.status, body: data },
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

export function validateSmsConfig(config: SmsConfig): void {
  if (config.provider !== MSG91_PROVIDER) {
    throw new Error(`Failed to send OTP SMS: unsupported SMS provider "${config.provider}"`);
  }
  const required = ['auth_key', 'sender_id', 'flow_id', 'otp_var_name', 'message_template'] as const;
  const missing = required.filter((f) => !String(config[f] || '').trim());
  if (missing.length) {
    throw new Error(
      `Failed to send OTP SMS: SMS configuration is incomplete (missing: ${missing.join(', ')})`,
    );
  }
  if (!config.message_template.includes('--')) {
    throw new Error('Failed to send OTP SMS: message_template must include -- as the OTP placeholder');
  }
}
