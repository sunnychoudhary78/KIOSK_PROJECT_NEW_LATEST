import { useEffect, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, EmptyState, Input, PageHeader, Panel, Select } from '../../core/ui/primitives';

type Device = {
  id: string;
  name: string;
  siteName: string;
};

type Segment = {
  id: string;
  filename: string;
  recordedOn: string;
  startedAt: string;
  byteSize: number;
  uploadedAt: string | null;
};

function todayUtc(): string {
  return new Date().toISOString().slice(0, 10);
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function RecordingsPage() {
  const { token } = useAuth();
  const [devices, setDevices] = useState<Device[]>([]);
  const [deviceId, setDeviceId] = useState('');
  const [recordedOn, setRecordedOn] = useState(todayUtc);
  const [items, setItems] = useState<Segment[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [playbackUrl, setPlaybackUrl] = useState<string | null>(null);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [playingLabel, setPlayingLabel] = useState<string | null>(null);

  useEffect(() => {
    void (async () => {
      try {
        const result = await apiRequest<{ items: Device[] }>('/devices', { token });
        setDevices(result.items);
        setDeviceId((current) => current || result.items[0]?.id || '');
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load kiosks');
      }
    })();
  }, [token]);

  useEffect(() => {
    if (!deviceId || !recordedOn) {
      setItems([]);
      return;
    }
    void (async () => {
      setLoading(true);
      setPlaybackUrl(null);
      setPlayingId(null);
      setPlayingLabel(null);
      try {
        const result = await apiRequest<{ items: Segment[] }>(
          `/devices/${deviceId}/surveillance/segments?recordedOn=${encodeURIComponent(recordedOn)}`,
          { token },
        );
        setItems(result.items);
        setError(null);
      } catch (err) {
        setItems([]);
        setError(err instanceof Error ? err.message : 'Failed to load recordings');
      } finally {
        setLoading(false);
      }
    })();
  }, [token, deviceId, recordedOn]);

  async function onPlay(segment: Segment) {
    setError(null);
    try {
      const result = await apiRequest<{ url: string; expiresAt: string }>(
        `/devices/${deviceId}/surveillance/segments/${segment.id}/playback-url`,
        { token },
      );
      setPlaybackUrl(result.url);
      setPlayingId(segment.id);
      setPlayingLabel(new Date(segment.startedAt).toLocaleString());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to get playback URL');
    }
  }

  return (
    <div>
      <PageHeader
        title="Recordings"
        subtitle="Browse uploaded kiosk surveillance clips by device and UTC calendar day"
      />

      <Panel>
        <div className="mb-4 grid gap-4 sm:grid-cols-2">
          <label>
            Kiosk
            <Select
              value={deviceId}
              onChange={(e) => setDeviceId(e.target.value)}
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
          <label>
            Date (UTC)
            <Input
              type="date"
              value={recordedOn}
              onChange={(e) => setRecordedOn(e.target.value)}
            />
          </label>
        </div>

        {error ? <p className="error mb-3">{error}</p> : null}
        {loading ? <p className="muted mb-3">Loading…</p> : null}

        {!loading && items.length === 0 ? (
          <EmptyState
            title="No uploaded clips"
            description="No recordings for this kiosk and UTC day."
          />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Started</th>
                <th>Filename</th>
                <th>Size</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {items.map((segment) => (
                <tr key={segment.id}>
                  <td>{new Date(segment.startedAt).toLocaleString()}</td>
                  <td>{segment.filename}</td>
                  <td>{formatBytes(segment.byteSize)}</td>
                  <td>
                    <Button type="button" onClick={() => void onPlay(segment)}>
                      {playingId === segment.id ? 'Playing' : 'Play'}
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        {playbackUrl ? (
          <div className="mt-5 space-y-3">
            <p className="text-sm text-muted-foreground">
              Playing {playingLabel ?? 'clip'} (signed URL expires after a few minutes)
            </p>
            <video
              key={playbackUrl}
              controls
              src={playbackUrl}
              className="max-h-[480px] w-full rounded-lg bg-black"
            />
            <p>
              <a href={playbackUrl} download target="_blank" rel="noreferrer">
                Download
              </a>
            </p>
          </div>
        ) : null}
      </Panel>
    </div>
  );
}
