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
  it('accepts default otp print config with 10 page / 30 min defaults', () => {
    const parsed = otpPrintConfigSchema.parse(DEFAULT_OTP_PRINT_CONFIG);
    expect(parsed.maxPagesPerSession).toBe(10);
    expect(parsed.ttlSeconds).toBe(1800);
    expect(parsed.freePagesPerSession).toBe(5);
    expect(parsed.extraPageChargeRupees).toBe(10);
  });

  it('fills new pricing fields when merging an older stored row', () => {
    const parsed = otpPrintConfigSchema.parse({
      ...DEFAULT_OTP_PRINT_CONFIG,
      ttlSeconds: 1800,
      otpLength: 6,
      maxPagesPerSession: 10,
      maxDocumentsPerSession: 5,
      maxVerifyAttempts: 5,
      maxFileSizeMb: 15,
    });
    expect(parsed.freePagesPerSession).toBe(5);
    expect(parsed.extraPageChargeRupees).toBe(10);
  });

  it('rejects free pages above the hard session cap', () => {
    const result = otpPrintConfigSchema.safeParse({
      ...DEFAULT_OTP_PRINT_CONFIG,
      freePagesPerSession: 20,
      maxPagesPerSession: 10,
    });
    expect(result.success).toBe(false);
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
