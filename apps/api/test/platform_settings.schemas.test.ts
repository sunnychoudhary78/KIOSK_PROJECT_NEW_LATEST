import { describe, expect, it } from 'vitest';
import {
  citizenAuthConfigSchema,
  otpPrintConfigSchema,
  smsConfigSchema,
} from '../src/modules/platform_settings/platform_settings.schemas.js';
import {
  DEFAULT_CITIZEN_AUTH_CONFIG,
  DEFAULT_OTP_PRINT_CONFIG,
} from '../src/modules/platform_settings/platform_settings.defaults.js';

describe('platform settings schemas', () => {
  it('accepts default otp print config with 10 page / 30 min defaults', () => {
    const parsed = otpPrintConfigSchema.parse(DEFAULT_OTP_PRINT_CONFIG);
    expect(parsed.maxPagesPerSession).toBe(10);
    expect(parsed.ttlSeconds).toBe(1800);
  });

  it('accepts citizen auth defaults', () => {
    expect(citizenAuthConfigSchema.parse(DEFAULT_CITIZEN_AUTH_CONFIG).requestCooldownSeconds).toBe(
      60,
    );
  });

  it('requires -- in SMS message template', () => {
    const result = smsConfigSchema.safeParse({
      provider: 'msg91',
      enabled: true,
      auth_key: 'k',
      sender_id: 'SENDER',
      flow_id: 'f',
      otp_var_name: 'OTP',
      message_template: 'no placeholder',
    });
    expect(result.success).toBe(false);
  });
});
