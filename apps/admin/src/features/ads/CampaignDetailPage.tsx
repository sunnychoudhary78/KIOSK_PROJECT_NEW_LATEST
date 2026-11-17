import { useEffect, useState, type FormEvent } from 'react';
import { Link, useParams } from 'react-router-dom';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  Input,
  PageHeader,
  Panel,
  StatusBadge,
} from '../../core/ui/primitives';
import { AdPreviewModal } from './AdPreviewModal';
import { formatDate, type Campaign, type Creative } from './types';

function toDatetimeLocalValue(value?: string | null): string {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function toIsoOrNull(localValue: string): string | null {
  if (!localValue) return null;
  const date = new Date(localValue);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

export function CampaignDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { token } = useAuth();
  const [campaign, setCampaign] = useState<Campaign | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [savingSchedule, setSavingSchedule] = useState(false);
  const [preview, setPreview] = useState<{ creative: Creative; slot: string } | null>(null);

  const [name, setName] = useState('');
  const [priority, setPriority] = useState(0);
  const [startsAt, setStartsAt] = useState('');
  const [endsAt, setEndsAt] = useState('');

  async function load() {
    if (!id) {
      return;
    }
    try {
      const detail = await apiRequest<Campaign>(`/ads/campaigns/${id}`, { token });
      setCampaign(detail);
      setName(detail.name);
      setPriority(detail.priority);
      setStartsAt(toDatetimeLocalValue(detail.startsAt));
      setEndsAt(toDatetimeLocalValue(detail.endsAt));
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load campaign');
    }
  }

  useEffect(() => {
    void load();
  }, [token, id]);

  async function setStatus(action: 'start' | 'pause' | 'end') {
    if (!id) {
      return;
    }
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await apiRequest(`/ads/campaigns/${id}/${action}`, { method: 'POST', token });
      await load();
      if (action === 'start') {
        setNotice('Campaign enabled. If the end date had expired, it was cleared so it can run again.');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : `Failed to ${action} campaign`);
    } finally {
      setBusy(false);
    }
  }

  async function saveSchedule(event: FormEvent) {
    event.preventDefault();
    if (!id) return;
    setSavingSchedule(true);
    setError(null);
    setNotice(null);
    try {
      const from = toIsoOrNull(startsAt);
      const to = toIsoOrNull(endsAt);
      if (from && to && new Date(from).getTime() > new Date(to).getTime()) {
        throw new Error('Start must be before end');
      }
      await apiRequest(`/ads/campaigns/${id}`, {
        method: 'PATCH',
        token,
        body: {
          name: name.trim(),
          priority,
          startsAt: from,
          endsAt: to,
        },
      });
      await load();
      setNotice('Schedule saved. Use Start / Resume to enable the campaign.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save schedule');
    } finally {
      setSavingSchedule(false);
    }
  }

  if (!campaign) {
    return (
      <div>
        <PageHeader title="Campaign" subtitle="Loading…" />
        {error ? <p className="error">{error}</p> : null}
      </div>
    );
  }

  const hasCreatives = (campaign.creatives?.length ?? 0) > 0;
  const hasTargets = (campaign.targets?.length ?? 0) > 0;
  const canStart =
    (campaign.status === 'draft' ||
      campaign.status === 'paused' ||
      campaign.status === 'scheduled' ||
      campaign.status === 'ended') &&
    hasCreatives &&
    hasTargets;
  const canPause = campaign.status === 'active' || campaign.status === 'scheduled';
  const canEnd = campaign.status !== 'ended';

  const startLabel =
    campaign.status === 'ended'
      ? 'Reactivate'
      : campaign.status === 'paused'
        ? 'Resume'
        : campaign.status === 'scheduled'
          ? 'Go live now'
          : 'Start';

  const analytics = campaign.analytics ?? {};
  const endsAtExpired =
    Boolean(campaign.endsAt) && new Date(campaign.endsAt!).getTime() < Date.now();

  return (
    <div>
      <PageHeader title={campaign.name} subtitle="Campaign detail, schedule, and delivery metrics" />

      {error ? <p className="error mb-3">{error}</p> : null}
      {notice ? <p className="success mb-3">{notice}</p> : null}

      <Panel
        title="Overview"
        actions={
          <>
            {canStart ? (
              <Button type="button" disabled={busy} onClick={() => void setStatus('start')}>
                {busy ? 'Working…' : startLabel}
              </Button>
            ) : null}
            {canPause ? (
              <Button
                type="button"
                variant="secondary"
                disabled={busy}
                onClick={() => void setStatus('pause')}
              >
                Pause
              </Button>
            ) : null}
            {canEnd ? (
              <Button
                type="button"
                variant="danger"
                disabled={busy}
                onClick={() => void setStatus('end')}
              >
                End
              </Button>
            ) : null}
          </>
        }
      >
        <p>
          <StatusBadge status={campaign.status} />
        </p>
        {campaign.status === 'ended' ? (
          <p className="muted mt-2">
            This campaign is ended. Update the schedule if needed, then click <strong>Reactivate</strong>.
          </p>
        ) : null}
        {endsAtExpired && campaign.status !== 'ended' ? (
          <p className="mt-2 text-sm text-amber-800">
            End date is in the past, so kiosks will not play this campaign until you extend or clear
            the end date and start again.
          </p>
        ) : null}
        <p className="muted">
          Advertiser:{' '}
          <Link to={`/advertisers/${campaign.advertiserId}`}>
            {campaign.advertiserName ?? campaign.advertiserId}
          </Link>
        </p>
        <p className="muted">Priority: {campaign.priority}</p>
        <p className="muted">
          Schedule: {formatDate(campaign.startsAt)} → {formatDate(campaign.endsAt)}
        </p>
        {!hasCreatives || !hasTargets ? (
          <p className="mt-2 text-sm text-amber-800">
            {!hasCreatives ? 'Attach creatives before enabling. ' : null}
            {!hasTargets ? 'Set targeting before enabling.' : null}
          </p>
        ) : null}
        <p>
          <Link to="/campaigns" className="text-sm font-medium text-primary hover:underline">
            Back to campaigns
          </Link>
        </p>
      </Panel>

      <Panel title="Schedule & settings">
        <form className="grid max-w-2xl gap-3 sm:grid-cols-2" onSubmit={(e) => void saveSchedule(e)}>
          <label className="sm:col-span-2">
            Name
            <Input value={name} onChange={(e) => setName(e.target.value)} required />
          </label>
          <label>
            Starts at
            <Input
              type="datetime-local"
              value={startsAt}
              onChange={(e) => setStartsAt(e.target.value)}
            />
          </label>
          <label>
            Ends at
            <Input
              type="datetime-local"
              value={endsAt}
              onChange={(e) => setEndsAt(e.target.value)}
            />
          </label>
          <label>
            Priority
            <Input
              type="number"
              min={0}
              max={1000}
              value={priority}
              onChange={(e) => setPriority(Number(e.target.value) || 0)}
            />
          </label>
          <div className="flex items-end gap-2 sm:col-span-2">
            <Button type="submit" disabled={savingSchedule}>
              {savingSchedule ? 'Saving…' : 'Save schedule'}
            </Button>
            <Button
              type="button"
              variant="ghost"
              disabled={savingSchedule || (!startsAt && !endsAt)}
              onClick={() => {
                setStartsAt('');
                setEndsAt('');
              }}
            >
              Clear dates
            </Button>
          </div>
          <p className="muted sm:col-span-2">
            Leave dates empty for immediate start and no end. After saving, use {startLabel} to apply
            status changes.
          </p>
        </form>
      </Panel>

      <Panel title="Analytics">
        <div className="stats-grid">
          <div className="stat-card">
            <strong>{analytics.impression ?? 0}</strong>
            <span>Impressions</span>
          </div>
          <div className="stat-card">
            <strong>{analytics.play_start ?? 0}</strong>
            <span>Play starts</span>
          </div>
          <div className="stat-card">
            <strong>{analytics.play_complete ?? 0}</strong>
            <span>Play completes</span>
          </div>
          <div className="stat-card">
            <strong>{analytics.click ?? 0}</strong>
            <span>Clicks</span>
          </div>
        </div>
      </Panel>

      <Panel title="Creatives">
        {(campaign.creatives ?? []).length === 0 ? (
          <p className="muted">No creatives attached. Recreate via New campaign wizard.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Slot</th>
                <th>Title</th>
                <th>Type</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {(campaign.creatives ?? []).map((link) => {
                const canPreview =
                  Boolean(link.creative.mediaUrl) || (link.creative.assets?.length ?? 0) > 0;
                return (
                  <tr key={`${link.slot}-${link.creative.id}`}>
                    <td>
                      <StatusBadge status={link.slot} />
                    </td>
                    <td>{link.creative.title}</td>
                    <td>{link.creative.type}</td>
                    <td className="text-right">
                      <Button
                        type="button"
                        variant="secondary"
                        className="h-8 px-3"
                        disabled={!canPreview}
                        onClick={() =>
                          setPreview({ creative: link.creative, slot: link.slot })
                        }
                      >
                        Preview
                      </Button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Panel>

      <Panel title="Targeting">
        {(campaign.targets ?? []).length === 0 ? (
          <p className="muted">No targets set.</p>
        ) : (
          <ul className="list">
            {(campaign.targets ?? []).map((t, index) => (
              <li key={index}>
                {t.targetAll
                  ? 'All kiosks'
                  : t.siteName
                    ? `Site: ${t.siteName}`
                    : t.deviceName
                      ? `Device: ${t.deviceName}`
                      : 'Target'}
              </li>
            ))}
          </ul>
        )}
      </Panel>

      <AdPreviewModal
        open={preview != null}
        creative={preview?.creative ?? null}
        slot={preview?.slot}
        onClose={() => setPreview(null)}
      />
    </div>
  );
}
