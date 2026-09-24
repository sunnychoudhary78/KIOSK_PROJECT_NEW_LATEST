import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Clapperboard, Megaphone, PlayCircle } from 'lucide-react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { PageHeader, Panel, StatusBadge } from '../../core/ui/primitives';

type Campaign = {
  id: string;
  name: string;
  status: string;
  advertiserName?: string;
  eventCount?: number;
};

export function DashboardPage() {
  const { token } = useAuth();
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void apiRequest<{ items: Campaign[] }>('/ads/campaigns', { token })
      .then((result) => {
        setCampaigns(result.items);
        setError(null);
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : 'Could not load campaign stats');
      });
  }, [token]);

  const active = campaigns.filter((c) => c.status === 'active');
  const totalEvents = campaigns.reduce((sum, c) => sum + (c.eventCount ?? 0), 0);

  return (
    <div>
      <PageHeader title="Dashboard" subtitle="Live snapshot of ads and campaign delivery" />

      {error ? <p className="error">{error}</p> : null}

      <div className="mb-5 grid gap-4 sm:grid-cols-3">
        <div className="stat-card">
          <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-foreground">
            <Clapperboard className="h-4 w-4" />
          </div>
          <strong>{active.length}</strong>
          <span>Active campaigns</span>
        </div>
        <div className="stat-card">
          <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-foreground">
            <Megaphone className="h-4 w-4" />
          </div>
          <strong>{campaigns.length}</strong>
          <span>Total campaigns</span>
        </div>
        <div className="stat-card">
          <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-foreground">
            <PlayCircle className="h-4 w-4" />
          </div>
          <strong>{totalEvents}</strong>
          <span>Playback events</span>
        </div>
      </div>

      <Panel
        title="Active campaigns"
        actions={
          <Link to="/campaigns" className="text-sm font-medium text-primary hover:underline">
            View all
          </Link>
        }
      >
        {active.length === 0 ? (
          <p className="muted">No campaigns are live. Start one from Campaigns when creatives and targets are ready.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Campaign</th>
                <th>Advertiser</th>
                <th>Status</th>
                <th>Events</th>
              </tr>
            </thead>
            <tbody>
              {active.map((c) => (
                <tr key={c.id}>
                  <td className="font-medium">
                    <Link to={`/campaigns/${c.id}`}>{c.name}</Link>
                  </td>
                  <td>{c.advertiserName ?? '—'}</td>
                  <td>
                    <StatusBadge status={c.status} />
                  </td>
                  <td>{c.eventCount ?? 0}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}
