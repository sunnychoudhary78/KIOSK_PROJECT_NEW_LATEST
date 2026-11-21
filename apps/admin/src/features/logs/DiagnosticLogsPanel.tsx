import { useCallback, useEffect, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
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
      onDeviceIdChange(devices[0].id);
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
    void loadLogs({ hours: 24, levelMode: 'problems', category: '' });
  }, [deviceId, loadLogs]);

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
        </div>

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
                  </tr>
                </thead>
                <tbody>
                  {items.map((row) => (
                    <tr key={row.id}>
                      <td className="whitespace-nowrap text-xs tabular-nums text-muted-foreground">
                        {new Date(row.occurredAt).toLocaleString()}
                      </td>
                      <td className="text-xs font-medium uppercase">{row.level}</td>
                      <td className="text-xs">{row.category}</td>
                      <td className="text-xs font-mono">{row.event}</td>
                      <td className="text-sm">{row.message}</td>
                    </tr>
                  ))}
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
        Raw machine logs (app.log) — coming in Phase 2
      </p>
    </div>
  );
}
