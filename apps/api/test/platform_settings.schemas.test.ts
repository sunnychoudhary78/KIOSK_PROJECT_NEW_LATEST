import { describe, expect, it } from 'vitest';
import {
  citizenAuthConfigSchema,
  otpPrintConfigSchema,
} from '../src/modules/platform_settings/platform_settings.schemas.js';
import {
  DEFAULT_CITIZEN_AUTH_CONFIG,
  DEFAULT_OTP_PRINT_CONFIG,
} from '../src/modules/platform_settings/platform_settings.defaults.js';

describe('platform settings schemas', () => {
  it('accepts default otp print config without page-price fields', () => {
    const parsed = otpPrintConfigSchema.parse(DEFAULT_OTP_PRINT_CONFIG);
    expect(parsed.ttlSeconds).toBe(1800);
    expect(parsed.otpLength).toBe(6);
    expect(parsed.maxDocumentsPerSession).toBe(5);
    expect(parsed.maxVerifyAttempts).toBe(5);
    expect(parsed.maxFileSizeMb).toBe(15);
    expect(parsed).not.toHaveProperty('maxPagesPerSession');
    expect(parsed).not.toHaveProperty('freePagesPerSession');
  });

  it('strips leftover page-price fields from an older stored row', () => {
    const parsed = otpPrintConfigSchema.parse({
      ...DEFAULT_OTP_PRINT_CONFIG,
      maxPagesPerSession: 10,
      freePagesPerSession: 5,
      extraPageChargeRupees: 10,
      freeColorPagesPerSession: 0,
      extraColorPageChargeRupees: 20,
    });
    expect(parsed.maxDocumentsPerSession).toBe(5);
    expect(parsed).not.toHaveProperty('maxPagesPerSession');
  });

  it('accepts citizen auth defaults', () => {
    expect(citizenAuthConfigSchema.parse(DEFAULT_CITIZEN_AUTH_CONFIG).requestCooldownSeconds).toBe(
      60,
    );
  });

  it('allows print OTP TTL up to 24 hours', () => {
    expect(otpPrintConfigSchema.parse({ ...DEFAULT_OTP_PRINT_CONFIG, ttlSeconds: 14_400 }).ttlSeconds).toBe(
      14_400,
    );
    expect(otpPrintConfigSchema.parse({ ...DEFAULT_OTP_PRINT_CONFIG, ttlSeconds: 18_000 }).ttlSeconds).toBe(
      18_000,
    );
  });

  it('rejects login OTP TTL above 1 hour', () => {
    const result = citizenAuthConfigSchema.safeParse({
      ...DEFAULT_CITIZEN_AUTH_CONFIG,
      ttlSeconds: 7200,
    });
    expect(result.success).toBe(false);
  });
});
