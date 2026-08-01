import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { PageHeader, Panel } from '../../core/ui/primitives';

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
      <PageHeader title="Dashboard" subtitle="Platform overview" />
      <Panel>
        <p>Monitor kiosks, print jobs, DigiLocker sessions, and ad campaigns from the sidebar.</p>
      </Panel>
      <Panel>
        <h2>Ads overview</h2>
        {error ? <p className="error">{error}</p> : null}
        <ul>
          <li>Active campaigns: {active.length}</li>
          <li>Total campaigns: {campaigns.length}</li>
          <li>Playback events recorded: {totalEvents}</li>
        </ul>
        <p>
          Manage creatives and targeting in <Link to="/campaigns">Campaigns</Link> ·{' '}
          <Link to="/advertisers">Advertisers</Link>
        </p>
        {active.length > 0 ? (
          <table className="table">
            <thead>
              <tr>
                <th>Active campaign</th>
                <th>Advertiser</th>
                <th>Events</th>
              </tr>
            </thead>
            <tbody>
              {active.map((c) => (
                <tr key={c.id}>
                  <td>{c.name}</td>
                  <td>{c.advertiserName ?? '—'}</td>
                  <td>{c.eventCount ?? 0}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : null}
      </Panel>
    </div>
  );
}
