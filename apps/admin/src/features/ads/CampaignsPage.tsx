import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  EmptyState,
  FilterChips,
  PageHeader,
  Panel,
  Select,
  StatusBadge,
  Toolbar,
} from '../../core/ui/primitives';
import { formatDate, type Advertiser, type Campaign } from './types';

const STATUS_FILTERS = [
  { value: 'all', label: 'All' },
  { value: 'draft', label: 'Draft' },
  { value: 'active', label: 'Active' },
  { value: 'paused', label: 'Paused' },
  { value: 'ended', label: 'Ended' },
];

export function CampaignsPage() {
  const { token } = useAuth();
  const navigate = useNavigate();
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [advertisers, setAdvertisers] = useState<Advertiser[]>([]);
  const [statusFilter, setStatusFilter] = useState('all');
  const [advertiserFilter, setAdvertiserFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void Promise.all([
      apiRequest<{ items: Campaign[] }>('/ads/campaigns', { token }),
      apiRequest<{ items: Advertiser[] }>('/ads/advertisers', { token }),
    ])
      .then(([cam, adv]) => {
        setCampaigns(cam.items);
        setAdvertisers(adv.items);
        setError(null);
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : 'Failed to load campaigns');
      });
  }, [token]);

  const filtered = useMemo(() => {
    return campaigns.filter((c) => {
      if (statusFilter !== 'all' && c.status !== statusFilter) {
        return false;
      }
      if (advertiserFilter !== 'all' && c.advertiserId !== advertiserFilter) {
        return false;
      }
      const q = search.trim().toLowerCase();
      if (!q) {
        return true;
      }
      return (
        c.name.toLowerCase().includes(q) ||
        (c.advertiserName ?? '').toLowerCase().includes(q)
      );
    });
  }, [campaigns, statusFilter, advertiserFilter, search]);

  return (
    <div>
      <PageHeader
        title="Campaigns"
        subtitle="Create, target, and run ad campaigns across kiosks"
      />

      {error ? <p className="error mb-4">{error}</p> : null}

      <Panel>
        <Toolbar
          search={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search campaigns"
          actions={
            <Button type="button" onClick={() => navigate('/campaigns/new')}>
              New campaign
            </Button>
          }
        >
          <FilterChips
            options={STATUS_FILTERS}
            value={statusFilter}
            onChange={setStatusFilter}
          />
          <Select
            value={advertiserFilter}
            onChange={(e) => setAdvertiserFilter(e.target.value)}
            aria-label="Filter by advertiser"
          >
            <option value="all">All advertisers</option>
            {advertisers.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name}
              </option>
            ))}
          </Select>
        </Toolbar>

        {filtered.length === 0 ? (
          <EmptyState
            title={campaigns.length === 0 ? 'No campaigns yet' : 'No matches'}
            description={
              campaigns.length === 0
                ? 'Use the guided wizard to attach creatives, choose kiosks, and go live.'
                : 'Adjust filters or search.'
            }
            action={
              campaigns.length === 0 ? (
                <Button type="button" onClick={() => navigate('/campaigns/new')}>
                  New campaign
                </Button>
              ) : null
            }
          />
        ) : (
          <table className="table table-clickable">
            <thead>
              <tr>
                <th>Name</th>
                <th>Advertiser</th>
                <th>Status</th>
                <th>Priority</th>
                <th>Events</th>
                <th>Updated</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((c) => (
                <tr key={c.id} onClick={() => navigate(`/campaigns/${c.id}`)}>
                  <td>{c.name}</td>
                  <td>{c.advertiserName ?? '—'}</td>
                  <td>
                    <StatusBadge status={c.status} />
                  </td>
                  <td>{c.priority}</td>
                  <td>{c.eventCount ?? 0}</td>
                  <td>{formatDate(c.updatedAt ?? c.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}
