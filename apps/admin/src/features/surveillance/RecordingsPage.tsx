import { useEffect, useMemo, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { pickDefaultDeviceId } from '../../core/kiosk/defaultKiosk';
import {
  Button,
  EmptyState,
  FilterChips,
  Input,
  Modal,
  PageHeader,
  PaginationBar,
  Panel,
  Select,
  Toolbar,
  paginateItems,
} from '../../core/ui/primitives';
import {
  labelForQueueCommand,
  resolveRecommendedQueueAction,
  resolveRecordingDisplay,
  resolveUploadBacklogWarning,
  SURVEILLANCE_QUEUE_ACTIONS,
  type SurveillanceHealth,
  type SurveillanceQueueCommandType,
} from './surveillanceStatus';

type SurveillanceCommand = {
  id: string;
  type: SurveillanceQueueCommandType;
  status: 'pending' | 'running' | 'succeeded' | 'failed' | 'expired';
  result?: Record<string, unknown> | null;
  lastError?: string | null;
};

type Device = {
  id: string;
  name: string;
  siteName: string;
  lastHeartbeatAt: string | null;
  surveillanceEnabled: boolean;
  surveillanceHealth?: SurveillanceHealth | null;
  surveillanceHealthAt?: string | null;
};

type Segment = {
  id: string;
  filename: string;
  recordedOn: string;
  startedAt: string;
  byteSize: number;
  status: 'uploaded' | 'pending_upload' | 'failed';
  uploadedAt: string | null;
  lastUploadError: string | null;
};

type DayPreset = 'today' | 'yesterday' | 'custom';

/** Local calendar day as YYYY-MM-DD (matches Started column timezone). */
function formatLocalDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function parseLocalDate(isoDate: string): Date {
  const [y, m, d] = isoDate.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function addLocalDays(isoDate: string, days: number): string {
  const dt = parseLocalDate(isoDate);
  dt.setDate(dt.getDate() + days);
  return formatLocalDate(dt);
}

function todayLocal(): string {
  return formatLocalDate(new Date());
}

function yesterdayLocal(): string {
  return addLocalDays(todayLocal(), -1);
}

/**
 * UTC `recordedOn` folder keys that can contain clips whose local startedAt
 * falls on `localDate` (needed for timezones east/west of UTC).
 */
function utcRecordedOnKeysForLocalDay(localDate: string): string[] {
  const start = parseLocalDate(localDate);
  const end = new Date(start);
  end.setHours(23, 59, 59, 999);
  return [...new Set([start.toISOString().slice(0, 10), end.toISOString().slice(0, 10)])].sort();
}

function startedAtOnLocalDay(startedAt: string, localDate: string): boolean {
  return formatLocalDate(new Date(startedAt)) === localDate;
}

function presetForDate(isoDate: string): DayPreset {
  if (isoDate === todayLocal()) return 'today';
  if (isoDate === yesterdayLocal()) return 'yesterday';
  return 'custom';
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function statusBadge(status: Segment['status']) {
  switch (status) {
    case 'uploaded':
      return (
        <span className="inline-flex rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-700">
          Uploaded
        </span>
      );
    case 'failed':
      return (
        <span className="inline-flex rounded-full bg-red-50 px-2 py-0.5 text-xs font-medium text-red-700">
          Failed
        </span>
      );
    default:
      return (
        <span className="inline-flex rounded-full bg-amber-50 px-2 py-0.5 text-xs font-medium text-amber-700">
          Pending
        </span>
      );
  }
}

export function RecordingsPage() {
  const { token } = useAuth();
  const [devices, setDevices] = useState<Device[]>([]);
  const [deviceId, setDeviceId] = useState('');
  const [recordedOn, setRecordedOn] = useState(todayLocal);
  const [dayPreset, setDayPreset] = useState<DayPreset>('today');
  const [items, setItems] = useState<Segment[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [playbackUrl, setPlaybackUrl] = useState<string | null>(null);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [playingLabel, setPlayingLabel] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<'all' | Segment['status']>('all');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);
  const [commandBusy, setCommandBusy] = useState(false);
  const [commandNote, setCommandNote] = useState<string | null>(null);
  const [moreOpen, setMoreOpen] = useState(false);
  const [flushConfirmOpen, setFlushConfirmOpen] = useState(false);
  const [dismissBusy, setDismissBusy] = useState(false);
  const [dismissTarget, setDismissTarget] = useState<Segment | null>(null);
  const [dismissOrphansOpen, setDismissOrphansOpen] = useState(false);

  const selected = devices.find((device) => device.id === deviceId) ?? null;
  const healthDisplay = selected ? resolveRecordingDisplay(selected) : null;
  const pendingOnKiosk = selected?.surveillanceHealth?.queuePending ?? 0;
  const backlogWarning = resolveUploadBacklogWarning(selected?.surveillanceHealth);
  const recommendedAction = resolveRecommendedQueueAction(selected?.surveillanceHealth);

  function applyDay(isoDate: string, preset?: DayPreset) {
    setRecordedOn(isoDate);
    setDayPreset(preset ?? presetForDate(isoDate));
  }

  useEffect(() => {
    void (async () => {
      try {
        const result = await apiRequest<{ items: Device[] }>('/devices', { token });
        setDevices(result.items);
        setDeviceId((current) => pickDefaultDeviceId(result.items, current));
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
        const keys = utcRecordedOnKeysForLocalDay(recordedOn);
        const batches = await Promise.all(
          keys.map((key) =>
            apiRequest<{ items: Segment[] }>(
              `/devices/${deviceId}/surveillance/segments?recordedOn=${encodeURIComponent(key)}&status=all`,
              { token },
            ),
          ),
        );
        const byId = new Map<string, Segment>();
        for (const batch of batches) {
          for (const segment of batch.items) {
            if (startedAtOnLocalDay(segment.startedAt, recordedOn)) {
              byId.set(segment.id, segment);
            }
          }
        }
        const merged = [...byId.values()].sort(
          (a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime(),
        );
        setItems(merged);
        setError(null);
      } catch (err) {
        setItems([]);
        setError(err instanceof Error ? err.message : 'Failed to load recordings');
      } finally {
        setLoading(false);
      }
    })();
  }, [token, deviceId, recordedOn]);

  async function refreshDevices() {
    const result = await apiRequest<{ items: Device[] }>('/devices', { token });
    setDevices(result.items);
  }

  async function waitForCommand(commandId: string) {
    const deadline = Date.now() + 90_000;
    while (Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 2000));
      const latest = await apiRequest<{ command: SurveillanceCommand | null }>(
        `/devices/${deviceId}/surveillance/commands/latest`,
        { token },
      );
      const command = latest.command;
      if (!command || command.id !== commandId) {
        continue;
      }
      if (command.status === 'succeeded') {
        const result = command.result ?? {};
        const parts = Object.entries(result)
          .filter(([, value]) => typeof value === 'number' && value > 0)
          .map(([key, value]) => `${key}=${value}`);
        setCommandNote(
          parts.length
            ? `Done: ${labelForQueueCommand(command.type)} (${parts.join(', ')})`
            : `Done: ${labelForQueueCommand(command.type)}`,
        );
        return;
      }
      if (command.status === 'failed' || command.status === 'expired') {
        throw new Error(command.lastError || `Command ${command.status}`);
      }
    }
    throw new Error('Timed out waiting for kiosk to run the command');
  }

  function requestQueueCommand(type: SurveillanceQueueCommandType) {
    if (type === 'flush_queue') {
      setMoreOpen(false);
      setFlushConfirmOpen(true);
      return;
    }
    void runQueueCommand(type);
  }

  async function runQueueCommand(type: SurveillanceQueueCommandType) {
    if (!deviceId || commandBusy) return;
    setCommandBusy(true);
    setCommandNote('Sending to kiosk…');
    setError(null);
    setMoreOpen(false);
    setFlushConfirmOpen(false);
    try {
      const created = await apiRequest<{ command: SurveillanceCommand }>(
        `/devices/${deviceId}/surveillance/commands`,
        { method: 'POST', token, body: { type } },
      );
      setCommandNote(`Waiting for kiosk (${labelForQueueCommand(type)})…`);
      await waitForCommand(created.command.id);
      await refreshDevices();
    } catch (err) {
      setCommandNote(null);
      setError(err instanceof Error ? err.message : 'Command failed');
    } finally {
      setCommandBusy(false);
    }
  }

  async function onPlay(segment: Segment) {
    if (segment.status !== 'uploaded') {
      setError('This clip is not uploaded yet');
      return;
    }
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

  function closePlayback() {
    setPlaybackUrl(null);
    setPlayingId(null);
    setPlayingLabel(null);
  }

  async function dismissSegment(segment: Segment) {
    if (!deviceId || dismissBusy) return;
    setDismissBusy(true);
    setError(null);
    try {
      await apiRequest<{ ok: true }>(
        `/devices/${deviceId}/surveillance/segments/${segment.id}/dismiss`,
        { method: 'POST', token },
      );
      setItems((current) => current.filter((row) => row.id !== segment.id));
      if (playingId === segment.id) {
        closePlayback();
      }
      setDismissTarget(null);
      setCommandNote(`Dismissed ${segment.filename}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to dismiss clip');
    } finally {
      setDismissBusy(false);
    }
  }

  async function dismissErroredPending() {
    if (!deviceId || dismissBusy) return;
    setDismissBusy(true);
    setError(null);
    try {
      const keys = utcRecordedOnKeysForLocalDay(recordedOn);
      let dismissed = 0;
      for (const key of keys) {
        const result = await apiRequest<{ ok: true; dismissed: number }>(
          `/devices/${deviceId}/surveillance/segments/dismiss-orphans`,
          { method: 'POST', token, body: { recordedOn: key } },
        );
        dismissed += result.dismissed;
      }
      setItems((current) =>
        current.filter((row) => row.status === 'uploaded' || row.lastUploadError == null),
      );
      setDismissOrphansOpen(false);
      setCommandNote(
        dismissed > 0
          ? `Dismissed ${dismissed} errored pending clip(s)`
          : 'No errored pending clips to dismiss',
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to dismiss errored pending');
    } finally {
      setDismissBusy(false);
    }
  }

  const uploadedCount = items.filter((item) => item.status === 'uploaded').length;
  const pendingCount = items.filter((item) => item.status === 'pending_upload').length;
  const failedCount = items.filter((item) => item.status === 'failed').length;
  const erroredPendingCount = items.filter(
    (item) => item.status !== 'uploaded' && item.lastUploadError != null,
  ).length;

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter((segment) => {
      if (statusFilter !== 'all' && segment.status !== statusFilter) return false;
      if (!q) return true;
      return [segment.filename, segment.status, segment.lastUploadError ?? '']
        .join(' ')
        .toLowerCase()
        .includes(q);
    });
  }, [items, statusFilter, search]);

  useEffect(() => {
    setPage(1);
  }, [deviceId, recordedOn, statusFilter, search, pageSize]);

  const paged = useMemo(
    () => paginateItems(filtered, page, pageSize),
    [filtered, page, pageSize],
  );

  return (
    <div>
      <PageHeader
        title="Recordings"
        subtitle="Browse kiosk surveillance clips by device and local calendar day"
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
          <div>
            <span className="mb-1 block text-sm font-medium">Date</span>
            <div className="flex flex-wrap items-center gap-2">
              <FilterChips
                options={[
                  { value: 'today', label: 'Today' },
                  { value: 'yesterday', label: 'Yesterday' },
                ]}
                value={dayPreset === 'custom' ? '' : dayPreset}
                onChange={(value) => {
                  if (value === 'today') applyDay(todayLocal(), 'today');
                  else if (value === 'yesterday') applyDay(yesterdayLocal(), 'yesterday');
                }}
              />
              <Input
                type="date"
                value={recordedOn}
                onChange={(e) => applyDay(e.target.value)}
                className="w-auto"
              />
            </div>
          </div>
        </div>

        {healthDisplay ? (
          <div className="mb-3 flex flex-wrap items-center gap-2">
            <p className={`text-sm font-medium ${healthDisplay.className}`} title={healthDisplay.title}>
              Live status: {healthDisplay.label}
              {pendingOnKiosk > 0 ? ` · ${pendingOnKiosk} clip(s) waiting on kiosk` : ''}
              {backlogWarning.ageLabel ? ` · oldest ${backlogWarning.ageLabel}` : ''}
              {backlogWarning.lastErrorCode ? ` · ${backlogWarning.lastErrorCode}` : ''}
              {backlogWarning.warn ? ' · backlog warning' : ''}
            </p>
            {selected?.surveillanceEnabled ? (
              <div className="flex flex-wrap items-center gap-2">
                {recommendedAction ? (
                  <Button
                    type="button"
                    variant="primary"
                    disabled={commandBusy}
                    onClick={() => requestQueueCommand(recommendedAction)}
                    title={
                      SURVEILLANCE_QUEUE_ACTIONS.find((a) => a.type === recommendedAction)
                        ?.description
                    }
                  >
                    {labelForQueueCommand(recommendedAction)}
                  </Button>
                ) : null}
                <div className="relative">
                  <Button
                    type="button"
                    variant="secondary"
                    disabled={commandBusy}
                    onClick={() => setMoreOpen((open) => !open)}
                  >
                    More
                  </Button>
                  {moreOpen ? (
                    <div className="absolute right-0 z-20 mt-1 min-w-[16rem] rounded-md border bg-white p-1 shadow-md">
                      {SURVEILLANCE_QUEUE_ACTIONS.map((action) => (
                        <button
                          key={action.type}
                          type="button"
                          className={`block w-full rounded px-3 py-2 text-left text-sm hover:bg-slate-50 disabled:opacity-50 ${
                            action.destructive ? 'text-red-700' : ''
                          }`}
                          disabled={commandBusy}
                          title={action.description}
                          onClick={() => requestQueueCommand(action.type)}
                        >
                          <span className="font-medium">{action.label}</span>
                          {recommendedAction === action.type ? (
                            <span className="ml-2 text-xs text-emerald-700">recommended</span>
                          ) : null}
                          <span className="mt-0.5 block text-xs text-slate-500">
                            {action.description}
                          </span>
                        </button>
                      ))}
                    </div>
                  ) : null}
                </div>
              </div>
            ) : null}
          </div>
        ) : null}

        {commandNote ? <p className="muted mb-3 text-sm">{commandNote}</p> : null}
        {error ? <p className="error mb-3">{error}</p> : null}
        {loading ? <p className="muted mb-3">Loading…</p> : null}

        {!loading && items.length === 0 ? (
          <EmptyState
            title={pendingOnKiosk > 0 ? 'Clips pending upload' : 'No clips for this day'}
            description={
              pendingOnKiosk > 0
                ? `${pendingOnKiosk} recording(s) are still on the kiosk waiting to upload${
                    backlogWarning.ageLabel ? ` (oldest ${backlogWarning.ageLabel})` : ''
                  }${backlogWarning.lastErrorCode ? ` · last error: ${backlogWarning.lastErrorCode}` : ''}.`
                : 'No recordings for this kiosk and local day.'
            }
          />
        ) : (
          <>
            {!loading && items.length > 0 ? (
              <>
                <p className="muted mb-3 text-sm">
                  {uploadedCount} uploaded · {pendingCount} pending · {failedCount} failed
                </p>
                <Toolbar
                  search={search}
                  onSearchChange={setSearch}
                  searchPlaceholder="Search filename or error"
                >
                  <FilterChips
                    options={[
                      { value: 'all', label: `All (${items.length})` },
                      { value: 'uploaded', label: `Uploaded (${uploadedCount})` },
                      { value: 'pending_upload', label: `Pending (${pendingCount})` },
                      { value: 'failed', label: `Failed (${failedCount})` },
                    ]}
                    value={statusFilter}
                    onChange={(value) => setStatusFilter(value as typeof statusFilter)}
                  />
                  {erroredPendingCount > 0 ? (
                    <Button
                      type="button"
                      variant="secondary"
                      disabled={dismissBusy}
                      onClick={() => setDismissOrphansOpen(true)}
                    >
                      Dismiss errored pending ({erroredPendingCount})
                    </Button>
                  ) : null}
                </Toolbar>
              </>
            ) : null}
            {!loading && items.length > 0 && filtered.length === 0 ? (
              <EmptyState title="No matches" description="Adjust status filter or search." />
            ) : (
              <>
                <table className="table">
                  <thead>
                    <tr>
                      <th>Started</th>
                      <th>Filename</th>
                      <th>Size</th>
                      <th>Status</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {paged.items.map((segment) => (
                      <tr key={segment.id}>
                        <td>{new Date(segment.startedAt).toLocaleString()}</td>
                        <td>{segment.filename}</td>
                        <td>{formatBytes(segment.byteSize)}</td>
                        <td>
                          <div className="flex flex-col gap-1">
                            {statusBadge(segment.status)}
                            {segment.lastUploadError ? (
                              <span className="text-xs text-muted-foreground">
                                {segment.lastUploadError}
                              </span>
                            ) : null}
                          </div>
                        </td>
                        <td>
                          <div className="flex flex-wrap items-center gap-2">
                            {segment.status === 'uploaded' ? (
                              <Button type="button" onClick={() => void onPlay(segment)}>
                                {playingId === segment.id ? 'Playing' : 'Play'}
                              </Button>
                            ) : (
                              <Button
                                type="button"
                                variant="secondary"
                                disabled={dismissBusy}
                                onClick={() => setDismissTarget(segment)}
                              >
                                Dismiss
                              </Button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                <PaginationBar
                  page={paged.page}
                  pageSize={pageSize}
                  total={filtered.length}
                  onPageChange={setPage}
                  onPageSizeChange={setPageSize}
                />
              </>
            )}
          </>
        )}
      </Panel>

      <Modal
        open={flushConfirmOpen}
        title="Flush upload queue?"
        description="Deletes clips still on the kiosk that have not uploaded, and clears the local upload queue. This cannot be undone."
        onClose={() => setFlushConfirmOpen(false)}
        footer={
          <>
            <Button type="button" variant="ghost" onClick={() => setFlushConfirmOpen(false)}>
              Cancel
            </Button>
            <Button
              type="button"
              variant="danger"
              disabled={commandBusy}
              onClick={() => void runQueueCommand('flush_queue')}
            >
              Flush queue
            </Button>
          </>
        }
      >
        <p className="text-sm text-muted-foreground">
          Use this only when heal / retry / clear stubs did not recover the kiosk. Uploaded cloud
          clips are not affected.
        </p>
      </Modal>

      <Modal
        open={dismissTarget != null}
        title="Dismiss this clip?"
        description="Removes this pending recording from the cloud list. Any partial upload object is deleted when possible. This cannot be undone."
        onClose={() => (dismissBusy ? undefined : setDismissTarget(null))}
        footer={
          <>
            <Button
              type="button"
              variant="ghost"
              disabled={dismissBusy}
              onClick={() => setDismissTarget(null)}
            >
              Cancel
            </Button>
            <Button
              type="button"
              variant="danger"
              disabled={dismissBusy || !dismissTarget}
              onClick={() => dismissTarget && void dismissSegment(dismissTarget)}
            >
              Dismiss
            </Button>
          </>
        }
      >
        {dismissTarget ? (
          <p className="text-sm text-muted-foreground">
            {dismissTarget.filename}
            {dismissTarget.lastUploadError ? ` · ${dismissTarget.lastUploadError}` : ''}
          </p>
        ) : null}
      </Modal>

      <Modal
        open={dismissOrphansOpen}
        title="Dismiss errored pending clips?"
        description={`Removes ${erroredPendingCount} pending clip(s) for this day that have an upload error. Healthy mid-upload rows without an error are left alone. This cannot be undone.`}
        onClose={() => (dismissBusy ? undefined : setDismissOrphansOpen(false))}
        footer={
          <>
            <Button
              type="button"
              variant="ghost"
              disabled={dismissBusy}
              onClick={() => setDismissOrphansOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="button"
              variant="danger"
              disabled={dismissBusy}
              onClick={() => void dismissErroredPending()}
            >
              Dismiss errored pending
            </Button>
          </>
        }
      >
        <p className="text-sm text-muted-foreground">
          Use this for stuck Pending · size_mismatch (or similar) rows when the kiosk queue is
          already clear.
        </p>
      </Modal>

      <Modal
        open={playbackUrl != null}
        title={playingLabel ? `Playback · ${playingLabel}` : 'Playback'}
        description="Signed URL expires after a few minutes"
        className="max-w-4xl"
        onClose={closePlayback}
        footer={
          <>
            {playbackUrl ? (
              <a
                href={playbackUrl}
                download
                target="_blank"
                rel="noreferrer"
                className="inline-flex h-8 items-center rounded-md px-3 text-sm text-muted-foreground hover:bg-accent hover:text-accent-foreground"
              >
                Download
              </a>
            ) : null}
            <Button type="button" variant="ghost" onClick={closePlayback}>
              Close
            </Button>
          </>
        }
      >
        {playbackUrl ? (
          <video
            key={playbackUrl}
            controls
            autoPlay
            src={playbackUrl}
            className="max-h-[min(70vh,36rem)] w-full rounded-lg bg-black"
          />
        ) : null}
      </Modal>
    </div>
  );
}
