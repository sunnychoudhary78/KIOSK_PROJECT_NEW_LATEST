import { describe, expect, it, vi } from 'vitest';
import {
  MSG91_FLOW_URL,
  createMsg91FlowSmsClient,
  isMsg91Configured,
  validateMsg91EnvConfig,
} from '../src/infrastructure/external/sms.client.js';
import type { Logger } from '../src/infrastructure/logging/logger.js';

const configuredMsg91 = {
  provider: 'msg91' as const,
  authKey: 'auth',
  senderId: 'SENDER',
  flowId: 'flow-123',
  otpVar: 'var1',
  expiryVar: 'var2',
};

describe('MSG91 SMS client', () => {
  it('validates required env fields', () => {
    expect(() =>
      validateMsg91EnvConfig({
        provider: 'msg91',
        authKey: '',
        senderId: 'SENDER',
        flowId: 'flow',
        otpVar: 'var1',
        expiryVar: 'var2',
      }),
    ).toThrow(/SKP_MSG91_AUTH_KEY/);

    expect(isMsg91Configured({ ...configuredMsg91, authKey: '' })).toBe(false);
    expect(isMsg91Configured(configuredMsg91)).toBe(true);
  });

  it('posts OTP and minutes-only expiry to MSG91 Flow', async () => {
    const fetchImpl = vi.fn(async (url: string | URL | Request) => {
      expect(String(url)).toBe(MSG91_FLOW_URL);
      return new Response(JSON.stringify({ type: 'success', message: 'req-1' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    });

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
      msg91: configuredMsg91,
      logger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });

    await client.sendOtp('+919999999999', '123456', 1200);

    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const [, init] = fetchImpl.mock.calls[0]!;
    const body = JSON.parse(String((init as RequestInit).body));
    expect(body.flow_id).toBe('flow-123');
    expect(body.recipients[0].mobiles).toBe('919999999999');
    expect(body.recipients[0].var1).toBe('123456');
    expect(body.recipients[0].var2).toBe('20 minutes');
  });

  it('formats long TTLs as hours', async () => {
    const fetchImpl = vi.fn(async () => {
      return new Response(JSON.stringify({ type: 'success', message: 'req-2' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    });

    const logger = { info: vi.fn() } as unknown as Logger;
    const client = createMsg91FlowSmsClient({
      msg91: configuredMsg91,
      logger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });

    await client.sendOtp('+919999999999', '654321', 14_400);

    const [, init] = fetchImpl.mock.calls[0]!;
    const body = JSON.parse(String((init as RequestInit).body));
    expect(body.recipients[0].var2).toBe('4 hours');
  });

  it('uses configurable Flow variable shortcodes', async () => {
    const fetchImpl = vi.fn(async () => {
      return new Response(JSON.stringify({ type: 'success', message: 'req-3' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    });

    const logger = { info: vi.fn() } as unknown as Logger;
    const client = createMsg91FlowSmsClient({
      msg91: {
        ...configuredMsg91,
        otpVar: 'OTP',
        expiryVar: 'TIME',
      },
      logger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
    });

    await client.sendOtp('+919999999999', '111222', 300);

    const [, init] = fetchImpl.mock.calls[0]!;
    const body = JSON.parse(String((init as RequestInit).body));
    expect(body.recipients[0].OTP).toBe('111222');
    expect(body.recipients[0].TIME).toBe('5 minutes');
    expect(body.recipients[0].var1).toBeUndefined();
    expect(body.recipients[0].var2).toBeUndefined();
  });

  it('noops when MSG91 not configured and allowed', async () => {
    const fetchImpl = vi.fn();
    const logger = { info: vi.fn() } as unknown as Logger;
    const client = createMsg91FlowSmsClient({
      msg91: {
        provider: 'noop',
        authKey: '',
        senderId: '',
        flowId: '',
        otpVar: 'var1',
        expiryVar: 'var2',
      },
      logger,
      fetchImpl: fetchImpl as unknown as typeof fetch,
      allowNoopWhenDisabled: true,
    });

    await client.sendOtp('+919999999999', '123456', 300);
    expect(fetchImpl).not.toHaveBeenCalled();
  });
});
