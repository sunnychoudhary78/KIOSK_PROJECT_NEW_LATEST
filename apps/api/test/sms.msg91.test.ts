import { describe, expect, it, vi } from 'vitest';
import {
  MSG91_FLOW_URL,
  createMsg91FlowSmsClient,
  validateSmsConfig,
} from '../src/infrastructure/external/sms.client.js';
import type { PlatformSettingsService } from '../src/modules/platform_settings/platform_settings.service.js';
import type { Logger } from '../src/infrastructure/logging/logger.js';

describe('MSG91 SMS client', () => {
  it('validates required Flow fields', () => {
    expect(() =>
      validateSmsConfig({
        provider: 'msg91',
        enabled: true,
        auth_key: '',
        sender_id: 'SENDER',
        flow_id: 'flow',
        otp_var_name: 'OTP',
        message_template: 'Your OTP is --',
      }),
    ).toThrow(/incomplete/i);

    expect(() =>
      validateSmsConfig({
        provider: 'msg91',
        enabled: true,
        auth_key: 'key',
        sender_id: 'SENDER',
        flow_id: 'flow',
        otp_var_name: 'OTP',
        message_template: 'Your OTP is missing placeholder',
      }),
    ).toThrow(/--/);
  });

  it('posts only to MSG91 Flow URL', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      expect(String(url)).toBe(MSG91_FLOW_URL);
      return new Response(JSON.stringify({ type: 'success', message: 'req-1' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    });

    const settings = {
      getSmsConfig: async () => ({
        provider: 'msg91' as const,
        enabled: true,
        auth_key: 'auth',
        sender_id: 'SENDER',
        flow_id: 'flow-123',
        otp_var_name: 'OTP',
        message_template: 'Your OTP is --',
      }),
    } as unknown as PlatformSettingsService;

    const logger = {
      info: vi.fn(),
      error: vi.fn(),
      warn: vi.fn(),
      debug: vi.fn(),
      fatal: vi.fn(),
      trace: vi.fn(),
      child: vi.fn(),
    } as unknown as Logger;

    const client = createMsg91FlowSmsClient({
      settings,
      logger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });

    await client.sendOtp('+919999999999', '123456');

    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const [, init] = fetchImpl.mock.calls[0]!;
    const body = JSON.parse(String((init as RequestInit).body));
    expect(body.flow_id).toBe('flow-123');
    expect(body.recipients[0].mobiles).toBe('919999999999');
    expect(body.recipients[0].OTP).toBe('123456');
  });

  it('noops when SMS disabled and allowed', async () => {
    const fetchImpl = vi.fn();
    const settings = {
      getSmsConfig: async () => ({
        provider: 'msg91' as const,
        enabled: false,
        auth_key: '',
        sender_id: '',
        flow_id: '',
        otp_var_name: 'OTP',
        message_template: 'Your OTP is --',
      }),
    } as unknown as PlatformSettingsService;

    const logger = { info: vi.fn() } as unknown as Logger;
    const client = createMsg91FlowSmsClient({
      settings,
      logger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
      allowNoopWhenDisabled: true,
    });

    await client.sendOtp('+919999999999', '123456');
    expect(fetchImpl).not.toHaveBeenCalled();
  });
});
