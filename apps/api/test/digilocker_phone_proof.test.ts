import { describe, expect, it } from 'vitest';
import {
  createDigiLockerPhoneProofToken,
  verifyDigiLockerPhoneProofToken,
} from '../src/modules/digilocker/digilocker_phone_proof.js';

const secret = 'test-jwt-secret-at-least-32-characters!!';

describe('digilocker phone proof token', () => {
  it('round-trips a valid token', () => {
    const token = createDigiLockerPhoneProofToken({
      deviceId: 'device-1',
      phone: '+919876543210',
      jwtSecret: secret,
      nowMs: 1_000_000,
    });
    const parsed = verifyDigiLockerPhoneProofToken({
      token,
      deviceId: 'device-1',
      jwtSecret: secret,
      nowMs: 1_000_000,
    });
    expect(parsed).toEqual({
      deviceId: 'device-1',
      phone: '+919876543210',
      exp: 1_000_000 + 10 * 60 * 1000,
    });
  });

  it('rejects expired and wrong-device tokens', () => {
    const token = createDigiLockerPhoneProofToken({
      deviceId: 'device-1',
      phone: '+919876543210',
      jwtSecret: secret,
      nowMs: 1_000_000,
      ttlMs: 1_000,
    });
    expect(
      verifyDigiLockerPhoneProofToken({
        token,
        deviceId: 'device-1',
        jwtSecret: secret,
        nowMs: 1_002_000,
      }),
    ).toBeNull();
    expect(
      verifyDigiLockerPhoneProofToken({
        token,
        deviceId: 'other-device',
        jwtSecret: secret,
        nowMs: 1_000_500,
      }),
    ).toBeNull();
  });
});
