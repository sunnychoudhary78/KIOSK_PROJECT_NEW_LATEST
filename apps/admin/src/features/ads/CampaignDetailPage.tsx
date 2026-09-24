import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  PageHeader,
  Panel,
  StatusBadge,
} from '../../core/ui/primitives';
import { formatDate, type Campaign } from './types';

export function CampaignDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { token } = useAuth();
  const [campaign, setCampaign] = useState<Campaign | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function load() {
    if (!id) {
      return;
    }
    try {
      const detail = await apiRequest<Campaign>(`/ads/campaigns/${id}`, { token });
      setCampaign(detail);
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
    try {
      await apiRequest(`/ads/campaigns/${id}/${action}`, { method: 'POST', token });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : `Failed to ${action} campaign`);
    } finally {
      setBusy(false);
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

  const canStart =
    (campaign.status === 'draft' || campaign.status === 'paused' || campaign.status === 'scheduled') &&
    (campaign.creatives?.length ?? 0) > 0 &&
    (campaign.targets?.length ?? 0) > 0;
  const canPause = campaign.status === 'active';
  const canEnd = campaign.status !== 'ended';

  const analytics = campaign.analytics ?? {};

  return (
    <div>
      <PageHeader title={campaign.name} subtitle="Campaign detail and delivery metrics" />

      {error ? <p className="error">{error}</p> : null}

      <Panel
        title="Overview"
        actions={
          <>
            {canStart ? (
              <Button type="button" disabled={busy} onClick={() => void setStatus('start')}>
                Start
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
        <p>
          <Link to="/campaigns" className="text-sm font-medium text-primary hover:underline">
            Back to campaigns
          </Link>
        </p>
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
              </tr>
            </thead>
            <tbody>
              {(campaign.creatives ?? []).map((link) => (
                <tr key={`${link.slot}-${link.creative.id}`}>
                  <td>
                    <StatusBadge status={link.slot} />
                  </td>
                  <td>{link.creative.title}</td>
                  <td>{link.creative.type}</td>
                </tr>
              ))}
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
    </div>
  );
}
