import { describe, expect, it } from 'vitest';
import type { AppConfig } from '../src/config/index.js';
import { createDigiLockerClient } from '../src/infrastructure/external/digilocker.client.js';

function testConfig(overrides?: Partial<AppConfig['digilocker']>): AppConfig {
  return {
    env: 'test',
    port: 3000,
    logLevel: 'error',
    databaseUrl: 'postgresql://skp:skp@localhost:5432/skp_test',
    auth: {
      jwtSecret: 'test-secret-must-be-at-least-32-chars!!',
      accessTtlSeconds: 3600,
      adminRefreshTtlSeconds: 43_200,
    },
    corsOrigins: ['http://localhost:5173'],
    printWeb: { publicUrl: 'http://localhost:5174' },
    otp: { ttlSeconds: 300, length: 6 },
    rateLimit: { windowMs: 60_000, max: 120 },
    digilocker: {
      baseUrl: 'https://digilocker.meripehchaan.gov.in',
      clientId: 'test-client-id',
      clientSecret: 'test-client-secret',
      redirectUri: 'http://localhost:3000/api/v1/auth/digilocker/callback',
      authorizePath: '/public/oauth2/1/authorize',
      tokenPath: '/public/oauth2/2/token',
      filesIssuedPath: '/public/oauth2/2/files/issued',
      filesUploadedPath: '/public/oauth2/1/files',
      filePathPrefix: '/public/oauth2/1/file',
      userPath: '/public/oauth2/1/user',
      eaadhaarPath: '/public/oauth2/3/xml/eaadhaar',
      scope: 'openid',
      purpose: 'Document printing at kiosk',
      serviceName: 'Athena Smart Kiosk',
      ...overrides,
    },
    smsProvider: 'noop',
    msg91: { authKey: '', senderId: '', flowId: '', otpVar: 'var1', expiryVar: 'var2' },
    razorpay: { keyId: '', keySecret: '', webhookSecret: '' },
    payments: { windowMinutes: 15 },
    vedastro: { baseUrl: 'https://api.vedastro.org/api', apiKey: '' },
    aiProvider: 'noop',
    openai: { apiKey: '', model: 'gpt-4o' },
    objectStorage: {
      endpoint: '',
      region: 'auto',
      bucket: '',
      accessKey: '',
      secretKey: '',
      putTtlSeconds: 3600,
      getTtlSeconds: 900,
    },
    kioskUpdateKey: '',
  };
}

describe('DigiLocker buildAuthorizeUrl', () => {
  it('includes mandatory purpose and service_name declarations', () => {
    const client = createDigiLockerClient(testConfig());
    const url = new URL(
      client.buildAuthorizeUrl({
        state: 'test-state',
        codeChallenge: 'test-challenge',
      }),
    );

    expect(url.searchParams.get('response_type')).toBe('code');
    expect(url.searchParams.get('client_id')).toBe('test-client-id');
    expect(url.searchParams.get('purpose')).toBe('Document printing at kiosk');
    expect(url.searchParams.get('service_name')).toBe('Athena Smart Kiosk');
    expect(url.searchParams.get('scope')).toBe('openid');
  });
});
