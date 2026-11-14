import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  EmptyState,
  FilterChips,
  Input,
  Modal,
  PageHeader,
  Panel,
  StatusBadge,
  Toolbar,
} from '../../core/ui/primitives';
import { CreativeUploadModal } from './CreativeUploadModal';
import { formatDate, type Advertiser, type Campaign, type Creative } from './types';

const CAMPAIGN_STATUS_FILTERS = [
  { value: 'all', label: 'All' },
  { value: 'draft', label: 'Draft' },
  { value: 'active', label: 'Active' },
  { value: 'paused', label: 'Paused' },
  { value: 'ended', label: 'Ended' },
];

export function AdvertiserDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { token } = useAuth();
  const navigate = useNavigate();
  const [advertiser, setAdvertiser] = useState<Advertiser | null>(null);
  const [creatives, setCreatives] = useState<Creative[]>([]);
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [creativeSearch, setCreativeSearch] = useState('');
  const [creativeTypeFilter, setCreativeTypeFilter] = useState('all');
  const [campaignSearch, setCampaignSearch] = useState('');
  const [campaignStatusFilter, setCampaignStatusFilter] = useState('all');
  const [error, setError] = useState<string | null>(null);
  const [editOpen, setEditOpen] = useState(false);
  const [uploadOpen, setUploadOpen] = useState(false);
  const [name, setName] = useState('');
  const [contactEmail, setContactEmail] = useState('');
  const [busy, setBusy] = useState(false);

  async function load() {
    if (!id) {
      return;
    }
    try {
      const [adv, cre, cam] = await Promise.all([
        apiRequest<Advertiser>(`/ads/advertisers/${id}`, { token }),
        apiRequest<{ items: Creative[] }>(`/ads/creatives?advertiserId=${id}`, { token }),
        apiRequest<{ items: Campaign[] }>('/ads/campaigns', { token }),
      ]);
      setAdvertiser(adv);
      setName(adv.name);
      setContactEmail(adv.contactEmail ?? '');
      setCreatives(cre.items);
      setCampaigns(cam.items.filter((c) => c.advertiserId === id));
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load advertiser');
    }
  }

  useEffect(() => {
    void load();
  }, [token, id]);

  async function onSave(event: FormEvent) {
    event.preventDefault();
    if (!id || !name.trim()) {
      return;
    }
    setBusy(true);
    try {
      await apiRequest(`/ads/advertisers/${id}`, {
        method: 'PATCH',
        token,
        body: { name: name.trim(), contactEmail: contactEmail.trim() || null },
      });
      setEditOpen(false);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save');
    } finally {
      setBusy(false);
    }
  }

  async function toggleActive() {
    if (!advertiser) {
      return;
    }
    setBusy(true);
    try {
      await apiRequest(`/ads/advertisers/${advertiser.id}`, {
        method: 'PATCH',
        token,
        body: { isActive: !advertiser.isActive },
      });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update status');
    } finally {
      setBusy(false);
    }
  }

  const creativeTypes = useMemo(() => {
    const values = Array.from(new Set(creatives.map((item) => item.type))).sort();
    return [
      { value: 'all', label: 'All types' },
      ...values.map((type) => ({ value: type, label: type.replace(/_/g, ' ') })),
    ];
  }, [creatives]);

  const filteredCreatives = useMemo(() => {
    const q = creativeSearch.trim().toLowerCase();
    return creatives.filter((item) => {
      if (creativeTypeFilter !== 'all' && item.type !== creativeTypeFilter) return false;
      if (!q) return true;
      return [item.title, item.type, item.mimeType ?? ''].join(' ').toLowerCase().includes(q);
    });
  }, [creatives, creativeSearch, creativeTypeFilter]);

  const filteredCampaigns = useMemo(() => {
    const q = campaignSearch.trim().toLowerCase();
    return campaigns.filter((item) => {
      if (campaignStatusFilter !== 'all' && item.status !== campaignStatusFilter) return false;
      if (!q) return true;
      return item.name.toLowerCase().includes(q);
    });
  }, [campaigns, campaignSearch, campaignStatusFilter]);

  if (!advertiser) {
    return (
      <div>
        <PageHeader title="Advertiser" subtitle="Loading…" />
        {error ? <p className="error">{error}</p> : null}
      </div>
    );
  }

  return (
    <div>
      <PageHeader
        title={advertiser.name}
        subtitle="Advertiser profile, creatives, and campaigns"
      />

      {error ? <p className="error">{error}</p> : null}

      <Panel
        title="Profile"
        actions={
          <>
            <Button type="button" variant="secondary" onClick={() => setEditOpen(true)}>
              Edit
            </Button>
            <Button type="button" variant="ghost" disabled={busy} onClick={() => void toggleActive()}>
              {advertiser.isActive ? 'Deactivate' : 'Activate'}
            </Button>
            <Button
              type="button"
              onClick={() => navigate(`/campaigns/new?advertiserId=${advertiser.id}`)}
            >
              New campaign
            </Button>
          </>
        }
      >
        <p>
          <StatusBadge status={advertiser.isActive ? 'active' : 'inactive'} />
        </p>
        <p className="muted">Contact: {advertiser.contactEmail ?? '—'}</p>
        <p className="muted">Created: {formatDate(advertiser.createdAt)}</p>
        <p className="muted">
          {advertiser.creativeCount ?? creatives.length} creatives ·{' '}
          {advertiser.campaignCount ?? campaigns.length} campaigns
        </p>
        <p>
          <Link to="/advertisers">← Back to advertisers</Link>
        </p>
      </Panel>

      <Panel
        title="Creatives library"
        actions={
          <Button type="button" variant="secondary" onClick={() => setUploadOpen(true)}>
            Upload creative
          </Button>
        }
      >
        {creatives.length === 0 ? (
          <EmptyState
            title="No creatives yet"
            description="Upload idle video/photos or horizontal/vertical home banners for campaigns."
            action={
              <Button type="button" onClick={() => setUploadOpen(true)}>
                Upload creative
              </Button>
            }
          />
        ) : (
          <>
            <Toolbar
              search={creativeSearch}
              onSearchChange={setCreativeSearch}
              searchPlaceholder="Search creatives"
            >
              <FilterChips
                options={creativeTypes}
                value={creativeTypeFilter}
                onChange={setCreativeTypeFilter}
              />
            </Toolbar>
            {filteredCreatives.length === 0 ? (
              <EmptyState title="No matches" description="Adjust creative filters or search." />
            ) : (
              <div className="creative-grid">
                {filteredCreatives.map((c) => {
                  const assetCount = c.assets?.length ?? 0;
                  return (
                    <div key={c.id} className="creative-card">
                      <h4>{c.title}</h4>
                      <p className="muted">
                        <StatusBadge status={c.type} />
                      </p>
                      <p className="muted">
                        {c.type === 'carousel'
                          ? `${assetCount} photos`
                          : (c.mimeType ?? 'media')}
                      </p>
                    </div>
                  );
                })}
              </div>
            )}
          </>
        )}
      </Panel>

      <Panel title="Campaigns">
        {campaigns.length === 0 ? (
          <EmptyState
            title="No campaigns"
            description="Create a campaign for this advertiser to start targeting kiosks."
            action={
              <Button
                type="button"
                onClick={() => navigate(`/campaigns/new?advertiserId=${advertiser.id}`)}
              >
                New campaign
              </Button>
            }
          />
        ) : (
          <>
            <Toolbar
              search={campaignSearch}
              onSearchChange={setCampaignSearch}
              searchPlaceholder="Search campaigns"
            >
              <FilterChips
                options={CAMPAIGN_STATUS_FILTERS}
                value={campaignStatusFilter}
                onChange={setCampaignStatusFilter}
              />
            </Toolbar>
            {filteredCampaigns.length === 0 ? (
              <EmptyState title="No matches" description="Adjust campaign filters or search." />
            ) : (
              <table className="table table-clickable">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Status</th>
                    <th>Events</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredCampaigns.map((c) => (
                    <tr key={c.id} onClick={() => navigate(`/campaigns/${c.id}`)}>
                      <td>{c.name}</td>
                      <td>
                        <StatusBadge status={c.status} />
                      </td>
                      <td>{c.eventCount ?? 0}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </>
        )}
      </Panel>

      <Modal
        open={editOpen}
        title="Edit advertiser"
        onClose={() => setEditOpen(false)}
        footer={
          <>
            <Button type="button" variant="ghost" onClick={() => setEditOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" form="edit-advertiser-form" disabled={busy}>
              Save
            </Button>
          </>
        }
      >
        <form id="edit-advertiser-form" className="stack" onSubmit={(e) => void onSave(e)}>
          <label>
            Name
            <Input value={name} onChange={(e) => setName(e.target.value)} required />
          </label>
          <label>
            Contact email
            <Input
              type="email"
              value={contactEmail}
              onChange={(e) => setContactEmail(e.target.value)}
            />
          </label>
        </form>
      </Modal>

      <CreativeUploadModal
        open={uploadOpen}
        advertiserId={advertiser.id}
        onClose={() => setUploadOpen(false)}
        onUploaded={() => {
          setUploadOpen(false);
          void load();
        }}
      />
    </div>
  );
}
