import { describe, expect, it } from 'vitest';
import { liveKitHttpHost } from '../src/modules/screen_share/livekit_tokens.js';

describe('liveKitHttpHost', () => {
  it('maps wss to https', () => {
    expect(liveKitHttpHost('wss://example.livekit.cloud')).toBe('https://example.livekit.cloud');
  });

  it('maps ws to http', () => {
    expect(liveKitHttpHost('ws://localhost:7880')).toBe('http://localhost:7880');
  });

  it('passes through other URLs', () => {
    expect(liveKitHttpHost('https://example.livekit.cloud')).toBe('https://example.livekit.cloud');
  });
});
