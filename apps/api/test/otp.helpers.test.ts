import { describe, expect, it } from 'vitest';
import {
  generateNumericOtp,
  hashOtp,
  normalizePhone,
  phoneDigits10,
  sanitizeOtpDeliveryError,
} from '../src/shared/otp.js';

describe('otp helpers', () => {
  it('normalizes indian phone numbers', () => {
    expect(normalizePhone('9999999999')).toBe('+919999999999');
    expect(normalizePhone('+91 99999 99999')).toBe('+919999999999');
    expect(normalizePhone('919999999999')).toBe('+919999999999');
    expect(phoneDigits10('+919999999999')).toBe('9999999999');
  });

  it('generates zero-padded numeric otps', () => {
    const code = generateNumericOtp(6);
    expect(code).toMatch(/^\d{6}$/);
    expect(hashOtp(code)).toHaveLength(64);
    expect(hashOtp(code)).toBe(hashOtp(code));
  });

  it('sanitizes SMS delivery errors', () => {
    expect(sanitizeOtpDeliveryError(new Error('SMS configuration is incomplete'))).toMatch(
      /not configured/i,
    );
    expect(sanitizeOtpDeliveryError(new Error('MSG91 SMS failed: timeout'))).toMatch(
      /Unable to send OTP SMS/i,
    );
  });
});
