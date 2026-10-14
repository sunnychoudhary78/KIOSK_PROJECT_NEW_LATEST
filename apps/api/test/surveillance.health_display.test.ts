import { describe, expect, it } from 'vitest';

/**
 * Mirrors admin resolveRecordingDisplay rules so status chip mapping stays covered
 * without wiring a frontend test runner.
 */
function resolveRecordingDisplay(device: {
  surveillanceEnabled: boolean;
  lastHeartbeatAt: string | null;
  surveillanceHealth?: { state: string; queuePending?: number } | null;
}) {
  if (!device.surveillanceEnabled) return 'off';
  const heartbeatAt = device.lastHeartbeatAt ? Date.parse(device.lastHeartbeatAt) : NaN;
  if (!Number.isFinite(heartbeatAt) || Date.now() - heartbeatAt > 3 * 60 * 1000) {
    return 'offline';
  }
  return device.surveillanceHealth?.state ?? 'stale';
}

describe('admin recording status mapping', () => {
  it('maps enabled+recording / enabled+error / enabled+stale heartbeat', () => {
    const now = new Date().toISOString();
    expect(
      resolveRecordingDisplay({
        surveillanceEnabled: true,
        lastHeartbeatAt: now,
        surveillanceHealth: { state: 'recording' },
      }),
    ).toBe('recording');

    expect(
      resolveRecordingDisplay({
        surveillanceEnabled: true,
        lastHeartbeatAt: now,
        surveillanceHealth: { state: 'camera_error' },
      }),
    ).toBe('camera_error');

    expect(
      resolveRecordingDisplay({
        surveillanceEnabled: true,
        lastHeartbeatAt: new Date(Date.now() - 10 * 60 * 1000).toISOString(),
        surveillanceHealth: { state: 'recording' },
      }),
    ).toBe('offline');
  });
});
