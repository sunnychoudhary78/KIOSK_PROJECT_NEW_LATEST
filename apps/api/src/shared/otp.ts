import { createHash, randomInt } from 'node:crypto';

export function hashOtp(code: string): string {
  return createHash('sha256').update(code).digest('hex');
}

export function generateNumericOtp(length: number): string {
  const max = 10 ** length;
  return String(randomInt(0, max)).padStart(length, '0');
}

/** Normalize to E.164-ish +91XXXXXXXXXX for Indian mobiles. */
export function normalizePhone(phone: string): string {
  const digits = phone.replace(/\D/g, '');
  if (digits.length === 10) {
    return `+91${digits}`;
  }
  if (digits.length === 12 && digits.startsWith('91')) {
    return `+${digits}`;
  }
  if (digits.length === 11 && digits.startsWith('0')) {
    return `+91${digits.slice(1)}`;
  }
  if (phone.startsWith('+') && digits.length >= 10) {
    return `+${digits}`;
  }
  throw new Error('invalid_phone');
}

export function phoneDigits10(phone: string): string {
  const normalized = normalizePhone(phone);
  const digits = normalized.replace(/\D/g, '');
  return digits.slice(-10);
}

export function sanitizeOtpDeliveryError(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  if (/incomplete|disabled|not configured/i.test(message)) {
    return 'SMS is not configured. Contact the operator.';
  }
  if (/MSG91|rate|timeout|network|fetch|ECONN/i.test(message)) {
    return 'Unable to send OTP SMS right now. Please try again.';
  }
  return 'Unable to send OTP. Please try again.';
}
