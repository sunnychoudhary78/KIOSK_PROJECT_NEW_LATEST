import { describe, expect, it } from 'vitest';
import { formatOtpExpiryLabel } from '../src/shared/otp.js';

describe('formatOtpExpiryLabel', () => {
  it('formats whole hours', () => {
    expect(formatOtpExpiryLabel(3600)).toBe('1 hour');
    expect(formatOtpExpiryLabel(14_400)).toBe('4 hours');
    expect(formatOtpExpiryLabel(18_000)).toBe('5 hours');
  });

  it('formats mixed hours and minutes', () => {
    expect(formatOtpExpiryLabel(5400)).toBe('1 hour 30 minutes');
    expect(formatOtpExpiryLabel(16_200)).toBe('4 hours 30 minutes');
    expect(formatOtpExpiryLabel(3660)).toBe('1 hour 1 minute');
  });

  it('formats minutes under one hour', () => {
    expect(formatOtpExpiryLabel(60)).toBe('1 minute');
    expect(formatOtpExpiryLabel(1200)).toBe('20 minutes');
    expect(formatOtpExpiryLabel(1800)).toBe('30 minutes');
  });

  it('rounds fractional minutes and floors invalid values to at least 1 minute', () => {
    expect(formatOtpExpiryLabel(90)).toBe('2 minutes');
    expect(formatOtpExpiryLabel(0)).toBe('1 minute');
    expect(formatOtpExpiryLabel(-10)).toBe('1 minute');
  });
});
