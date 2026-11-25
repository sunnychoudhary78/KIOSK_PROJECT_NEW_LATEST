import { useCallback, useEffect, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { pickDefaultDeviceId } from '../../core/kiosk/defaultKiosk';
import { Button, EmptyState, Panel, Select } from '../../core/ui/primitives';

type DeviceOption = {
  id: string;
  name: string;
  siteName: string;
};

type DiagnosticLogItem = {
  id: string;
  occurredAt: string;
  level: string;
  category: string;
  event: string;
  message: string;
  correlationId: string | null;
  metadata: unknown;
};

function metadataSummary(metadata: unknown): string | null {
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) return null;
  const record = metadata as Record<string, unknown>;
  const preferred = ['jobId', 'title', 'source', 'detail', 'pagesReported', 'error', 'reason'];
  const parts: string[] = [];
  for (const key of preferred) {
    const value = record[key];
    if (value == null || value === '') continue;
    if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
      parts.push(`${key}: ${value}`);
    }
  }
  if (parts.length > 0) return parts.join(' · ');
  try {
    const raw = JSON.stringify(record);
    return raw === '{}' ? null : raw.length > 140 ? `${raw.slice(0, 140)}…` : raw;
  } catch {
    return null;
  }
}

type DiagnosticLogsPanelProps = {
  deviceId: string;
  onDeviceIdChange: (deviceId: string) => void;
};

export function DiagnosticLogsPanel({ deviceId, onDeviceIdChange }: DiagnosticLogsPanelProps) {
  const { token } = useAuth();
  const [devices, setDevices] = useState<DeviceOption[]>([]);
  const [devicesError, setDevicesError] = useState<string | null>(null);
  const [hours, setHours] = useState<24 | 168>(24);
  const [levelMode, setLevelMode] = useState<'problems' | 'all'>('problems');
  const [category, setCategory] = useState('');
  const [items, setItems] = useState<DiagnosticLogItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [nextBefore, setNextBefore] = useState<string | null>(null);
  const [nextBeforeId, setNextBeforeId] = useState<string | null>(null);
  const [collectBusy, setCollectBusy] = useState(false);
  const [collectNote, setCollectNote] = useState<string | null>(null);
  const [bundleId, setBundleId] = useState<string | null>(null);
  const [downloadBusy, setDownloadBusy] = useState(false);

  useEffect(() => {
    void (async () => {
      try {
        const result = await apiRequest<{ items: DeviceOption[] }>('/devices', { token });
        setDevices(result.items);
        setDevicesError(null);
      } catch (err) {
        setDevicesError(err instanceof Error ? err.message : 'Failed to load kiosks');
      }
    })();
  }, [token]);

  useEffect(() => {
    if (devices.length === 0) return;
    if (!deviceId || !devices.some((device) => device.id === deviceId)) {
      onDeviceIdChange(pickDefaultDeviceId(devices, deviceId));
    }
  }, [devices, deviceId, onDeviceIdChange]);

  const loadLogs = useCallback(
    async (opts: {
      hours: 24 | 168;
      levelMode: 'problems' | 'all';
      category: string;
      append?: boolean;
      before?: string | null;
      beforeId?: string | null;
    }) => {
      if (!deviceId) {
        setItems([]);
        return;
      }
      const appending = opts.append === true;
      if (appending) {
        setLoadingMore(true);
      } else {
        setLoading(true);
        setError(null);
      }
      try {
        const to = new Date();
        const from = new Date(to.getTime() - opts.hours * 60 * 60 * 1000);
        const params = new URLSearchParams({
          from: from.toISOString(),
          to: to.toISOString(),
          limit: '100',
        });
        if (opts.levelMode === 'problems') {
          params.set('levels', 'error,warn');
        }
        if (opts.category) {
          params.set('category', opts.category);
        }
        if (opts.before) {
          params.set('before', opts.before);
        }
        if (opts.beforeId) {
          params.set('beforeId', opts.beforeId);
        }
        const result = await apiRequest<{
          items: DiagnosticLogItem[];
          hasMore: boolean;
          nextBefore: string | null;
          nextBeforeId: string | null;
        }>(`/devices/${deviceId}/diagnostic-logs?${params.toString()}`, { token });
        setItems((prev) =>
          appending ? [...prev, ...(result.items ?? [])] : (result.items ?? []),
        );
        setHasMore(Boolean(result.hasMore));
        setNextBefore(result.nextBefore ?? null);
        setNextBeforeId(result.nextBeforeId ?? null);
      } catch (err) {
        if (!appending) {
          setItems([]);
        }
        setError(err instanceof Error ? err.message : 'Failed to load logs');
      } finally {
        setLoading(false);
        setLoadingMore(false);
      }
    },
    [deviceId, token],
  );

  useEffect(() => {
    if (!deviceId) return;
    setHours(24);
    setLevelMode('problems');
    setCategory('');
    setHasMore(false);
    setNextBefore(null);
    setNextBeforeId(null);
    setBundleId(null);
    setCollectNote(null);
    void loadLogs({ hours: 24, levelMode: 'problems', category: '' });
  }, [deviceId, loadLogs]);

  async function waitForCollectCommand(commandId: string) {
    const deadline = Date.now() + 10 * 60 * 1000;
    while (Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 2000));
      const latest = await apiRequest<{
        command: {
          id: string;
          type: string;
          status: string;
          result?: Record<string, unknown> | null;
          lastError?: string | null;
        } | null;
      }>(`/devices/${deviceId}/surveillance/commands/latest`, { token });
      const command = latest.command;
      if (!command || command.id !== commandId) {
        continue;
      }
      if (command.status === 'succeeded') {
        return command.result ?? {};
      }
      if (command.status === 'failed' || command.status === 'expired') {
        throw new Error(command.lastError || `Command ${command.status}`);
      }
    }
    throw new Error('Timed out waiting for kiosk to collect diagnostics');
  }

  async function collectDiagnostics() {
    if (!deviceId || collectBusy) return;
    setCollectBusy(true);
    setCollectNote('Sending collect command…');
    setError(null);
    setBundleId(null);
    try {
      const created = await apiRequest<{
        command: { id: string };
      }>(`/devices/${deviceId}/surveillance/commands`, {
        method: 'POST',
        token,
        body: { type: 'collect_diagnostics' },
      });
      setCollectNote('Waiting for kiosk to zip and upload…');
      const result = await waitForCollectCommand(created.command.id);
      const nextBundleId =
        typeof result.bundleId === 'string' ? result.bundleId : null;
      const inventoryCount =
        typeof result.inventoryCount === 'number' ? result.inventoryCount : null;
      setBundleId(nextBundleId);
      setCollectNote(
        nextBundleId
          ? `Ready to download${
              inventoryCount != null ? ` · ${inventoryCount} local recording(s)` : ''
            }`
          : 'Collect finished but no bundle id was returned',
      );
    } catch (err) {
      setCollectNote(null);
      setError(err instanceof Error ? err.message : 'Failed to collect diagnostics');
    } finally {
      setCollectBusy(false);
    }
  }

  async function downloadBundle() {
    if (!deviceId || !bundleId || downloadBusy) return;
    setDownloadBusy(true);
    setError(null);
    try {
      const result = await apiRequest<{ url: string; expiresAt: string }>(
        `/devices/${deviceId}/diagnostic-bundles/${bundleId}/download-url`,
        { token },
      );
      window.open(result.url, '_blank', 'noopener,noreferrer');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to get download URL');
    } finally {
      setDownloadBusy(false);
    }
  }

  return (
    <div>
      <Panel>
        <div className="mb-4 grid gap-4 sm:grid-cols-2">
          <label>
            Kiosk
            <Select
              value={deviceId}
              onChange={(e) => onDeviceIdChange(e.target.value)}
              disabled={devices.length === 0}
            >
              {devices.length === 0 ? <option value="">No kiosks</option> : null}
              {devices.map((device) => (
                <option key={device.id} value={device.id}>
                  {device.name} ({device.siteName})
                </option>
              ))}
            </Select>
          </label>
          <div className="flex flex-wrap items-end gap-2">
            <Button
              type="button"
              variant="primary"
              disabled={!deviceId || collectBusy}
              onClick={() => void collectDiagnostics()}
            >
              {collectBusy ? 'Collecting…' : 'Collect diagnostics'}
            </Button>
            {bundleId ? (
              <Button
                type="button"
                variant="secondary"
                disabled={downloadBusy}
                onClick={() => void downloadBundle()}
              >
                {downloadBusy ? 'Opening…' : 'Download zip'}
              </Button>
            ) : null}
          </div>
        </div>
        {collectNote ? <p className="muted mb-3 text-sm">{collectNote}</p> : null}

        <div className="mb-4 flex flex-wrap items-center gap-2">
          <span className="text-sm text-muted-foreground">Range</span>
          <Button
            type="button"
            variant={hours === 24 ? 'primary' : 'secondary'}
            className="h-8 px-3"
            disabled={loading || !deviceId}
            onClick={() => {
              setHours(24);
              void loadLogs({ hours: 24, levelMode, category });
            }}
          >
            Last 24h
          </Button>
          <Button
            type="button"
            variant={hours === 168 ? 'primary' : 'secondary'}
            className="h-8 px-3"
            disabled={loading || !deviceId}
            onClick={() => {
              setHours(168);
              void loadLogs({ hours: 168, levelMode, category });
            }}
          >
            Last 7 days
          </Button>
          <span className="ml-2 text-sm text-muted-foreground">Level</span>
          <Button
            type="button"
            variant={levelMode === 'problems' ? 'primary' : 'secondary'}
            className="h-8 px-3"
            disabled={loading || !deviceId}
            onClick={() => {
              setLevelMode('problems');
              void loadLogs({ hours, levelMode: 'problems', category });
            }}
          >
            Errors + warnings
          </Button>
          <Button
            type="button"
            variant={levelMode === 'all' ? 'primary' : 'secondary'}
            className="h-8 px-3"
            disabled={loading || !deviceId}
            onClick={() => {
              setLevelMode('all');
              void loadLogs({ hours, levelMode: 'all', category });
            }}
          >
            All levels
          </Button>
          <span className="ml-2 text-sm text-muted-foreground">Category</span>
          <select
            className="h-8 rounded-md border border-border bg-background px-2 text-sm"
            value={category}
            disabled={loading || !deviceId}
            onChange={(e) => {
              const next = e.target.value;
              setCategory(next);
              void loadLogs({ hours, levelMode, category: next });
            }}
          >
            <option value="">All</option>
            <option value="printer">Printer</option>
            <option value="astrology">Astrology</option>
            <option value="well_being">Well-being</option>
            <option value="shutter">Shutter</option>
            <option value="cabinet_light">Cabinet light</option>
            <option value="charging">Charging</option>
            <option value="serial">Serial</option>
            <option value="app">App</option>
          </select>
        </div>

        {devicesError ? <p className="error mb-3">{devicesError}</p> : null}
        {error ? <p className="error mb-3">{error}</p> : null}
        {loading ? (
          <p className="text-muted-foreground">Loading logs…</p>
        ) : items.length === 0 ? (
          <EmptyState
            title="No diagnostic logs yet"
            description="Errors and warnings from this kiosk appear here (kept for 7 days)."
          />
        ) : (
          <div className="space-y-3">
            <div className="overflow-x-auto">
              <table className="table w-full">
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>Level</th>
                    <th>Category</th>
                    <th>Event</th>
                    <th>Message</th>
                    <th>Details</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((row) => {
                    const details = metadataSummary(row.metadata);
                    return (
                      <tr key={row.id}>
                        <td className="whitespace-nowrap text-xs tabular-nums text-muted-foreground">
                          {new Date(row.occurredAt).toLocaleString()}
                        </td>
                        <td className="text-xs font-medium uppercase">{row.level}</td>
                        <td className="text-xs">{row.category}</td>
                        <td className="text-xs font-mono">{row.event}</td>
                        <td className="text-sm">{row.message}</td>
                        <td className="max-w-[18rem] text-xs text-muted-foreground">
                          {details ?? '—'}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            {hasMore ? (
              <Button
                type="button"
                variant="secondary"
                className="h-8 px-3"
                disabled={loadingMore || !deviceId}
                onClick={() => {
                  void loadLogs({
                    hours,
                    levelMode,
                    category,
                    append: true,
                    before: nextBefore,
                    beforeId: nextBeforeId,
                  });
                }}
              >
                {loadingMore ? 'Loading…' : 'Load more'}
              </Button>
            ) : null}
          </div>
        )}
      </Panel>
      <p className="muted mt-3 text-sm">
        Collect downloads app.log (+ rotations), upload-queue.json, and a local recordings
        inventory (no MP4s). Bundles expire after 7 days.
      </p>
    </div>
  );
}
