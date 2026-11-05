import { createHmac, timingSafeEqual } from 'node:crypto';

const PROOF_TTL_MS = 10 * 60 * 1000;
const PROOF_PREFIX = 'well_being_phone_v1';

export type WellBeingPhoneProofPayload = {
  deviceId: string;
  phone: string;
  exp: number;
};

function sign(secret: string, body: string): string {
  return createHmac('sha256', secret).update(body).digest('base64url');
}

export function createWellBeingPhoneProofToken(input: {
  deviceId: string;
  phone: string;
  jwtSecret: string;
  nowMs?: number;
  ttlMs?: number;
}): string {
  const now = input.nowMs ?? Date.now();
  const exp = now + (input.ttlMs ?? PROOF_TTL_MS);
  const payload = Buffer.from(
    JSON.stringify({
      deviceId: input.deviceId,
      phone: input.phone,
      exp,
    } satisfies WellBeingPhoneProofPayload),
  ).toString('base64url');
  const sig = sign(input.jwtSecret, `${PROOF_PREFIX}.${payload}`);
  return `${payload}.${sig}`;
}

export function verifyWellBeingPhoneProofToken(input: {
  token: string;
  deviceId: string;
  jwtSecret: string;
  nowMs?: number;
}): WellBeingPhoneProofPayload | null {
  const parts = input.token.split('.');
  if (parts.length !== 2) {
    return null;
  }
  const [payloadPart, sigPart] = parts;
  if (!payloadPart || !sigPart) {
    return null;
  }
  const expected = sign(input.jwtSecret, `${PROOF_PREFIX}.${payloadPart}`);
  try {
    const a = Buffer.from(sigPart);
    const b = Buffer.from(expected);
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      return null;
    }
  } catch {
    return null;
  }

  let parsed: WellBeingPhoneProofPayload;
  try {
    parsed = JSON.parse(
      Buffer.from(payloadPart, 'base64url').toString('utf8'),
    ) as WellBeingPhoneProofPayload;
  } catch {
    return null;
  }
  if (
    typeof parsed.deviceId !== 'string' ||
    typeof parsed.phone !== 'string' ||
    typeof parsed.exp !== 'number'
  ) {
    return null;
  }
  if (parsed.deviceId !== input.deviceId) {
    return null;
  }
  if ((input.nowMs ?? Date.now()) > parsed.exp) {
    return null;
  }
  return parsed;
}
