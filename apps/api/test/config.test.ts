import { describe, expect, it } from 'vitest';
import { loadConfig, resetConfigCache } from '../src/config/index.js';

describe('loadConfig', () => {
  it('loads typed configuration from env', () => {
    resetConfigCache();
    const config = loadConfig({
      SKP_NODE_ENV: 'test',
      SKP_PORT: '4000',
      SKP_LOG_LEVEL: 'error',
      SKP_DATABASE_URL: 'postgresql://skp:skp@localhost:5432/skp_test',
      SKP_JWT_SECRET: 'test-secret-must-be-at-least-32-chars!!',
      SKP_JWT_ACCESS_TTL_SECONDS: '1800',
      SKP_CORS_ORIGINS: 'http://localhost:5173',
      SKP_OTP_TTL_SECONDS: '120',
      SKP_OTP_LENGTH: '6',
      SKP_RATE_LIMIT_WINDOW_MS: '60000',
      SKP_RATE_LIMIT_MAX: '60',
      SKP_DIGILOCKER_BASE_URL: 'https://digilocker.meripehchaan.gov.in',
      SKP_DIGILOCKER_CLIENT_ID: 'id',
      SKP_DIGILOCKER_CLIENT_SECRET: 'secret',
      SKP_DIGILOCKER_REDIRECT_URI: 'http://localhost:3000/api/v1/auth/digilocker/callback',
      SKP_SMS_PROVIDER: 'noop',
      SKP_MSG91_AUTH_KEY: 'test-key',
      SKP_MSG91_SENDER_ID: 'IMRTPS',
      SKP_MSG91_FLOW_ID: 'flow-abc',
      SKP_MSG91_OTP_VAR: 'OTP',
      SKP_MSG91_EXPIRY_VAR: 'TIME',
    });

    expect(config.port).toBe(4000);
    expect(config.auth.accessTtlSeconds).toBe(1800);
    expect(config.otp.length).toBe(6);
    expect(config.msg91).toEqual({
      authKey: 'test-key',
      senderId: 'IMRTPS',
      flowId: 'flow-abc',
      otpVar: 'OTP',
      expiryVar: 'TIME',
    });
    expect(config.razorpay).toEqual({
      keyId: '',
      keySecret: '',
      webhookSecret: '',
    });
    expect(config.printWeb.publicUrl).toBe('http://localhost:5174');
    expect(config.payments.windowMinutes).toBe(15);
    expect(config.vedastro.baseUrl).toBe('https://api.vedastro.org/api');
    expect(config.aiProvider).toBe('noop');
    expect(config.openai).toEqual({
      apiKey: '',
      model: 'gpt-4o',
    });
    expect(config.objectStorage).toEqual({
      endpoint: '',
      region: 'auto',
      bucket: '',
      accessKey: '',
      secretKey: '',
      putTtlSeconds: 3600,
      getTtlSeconds: 900,
    });
  });
});
