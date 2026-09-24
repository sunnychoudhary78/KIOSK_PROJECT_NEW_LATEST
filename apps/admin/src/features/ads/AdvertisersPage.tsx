import { useEffect, useMemo, useState, type FormEvent, type MouseEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  EmptyState,
  Input,
  Modal,
  PageHeader,
  Panel,
  StatusBadge,
  Toolbar,
} from '../../core/ui/primitives';
import { formatDate, type Advertiser } from './types';

export function AdvertisersPage() {
  const { token } = useAuth();
  const navigate = useNavigate();
  const [items, setItems] = useState<Advertiser[]>([]);
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [name, setName] = useState('');
  const [contactEmail, setContactEmail] = useState('');
  const [submitting, setSubmitting] = useState(false);

  async function load() {
    try {
      const result = await apiRequest<{ items: Advertiser[] }>('/ads/advertisers', { token });
      setItems(result.items);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load advertisers');
    }
  }

  useEffect(() => {
    void load();
  }, [token]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) {
      return items;
    }
    return items.filter(
      (item) =>
        item.name.toLowerCase().includes(q) ||
        (item.contactEmail ?? '').toLowerCase().includes(q),
    );
  }, [items, search]);

  async function onCreate(event: FormEvent) {
    event.preventDefault();
    if (!name.trim()) {
      setError('Name is required');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const created = await apiRequest<Advertiser>('/ads/advertisers', {
        method: 'POST',
        token,
        body: {
          name: name.trim(),
          contactEmail: contactEmail.trim() || null,
        },
      });
      setModalOpen(false);
      setName('');
      setContactEmail('');
      await load();
      navigate(`/advertisers/${created.id}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create advertiser');
    } finally {
      setSubmitting(false);
    }
  }

  async function toggleActive(item: Advertiser, event: MouseEvent) {
    event.stopPropagation();
    try {
      await apiRequest(`/ads/advertisers/${item.id}`, {
        method: 'PATCH',
        token,
        body: { isActive: !item.isActive },
      });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update advertiser');
    }
  }

  return (
    <div>
      <PageHeader
        title="Advertisers"
        subtitle="Clients and brands that run kiosk ad campaigns"
      />

      {error ? <p className="error mb-4">{error}</p> : null}

      <Panel>
        <Toolbar
          search={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search by name or email"
          actions={
            <Button type="button" onClick={() => setModalOpen(true)}>
              New advertiser
            </Button>
          }
        />

        {filtered.length === 0 ? (
          <EmptyState
            title={items.length === 0 ? 'No advertisers yet' : 'No matches'}
            description={
              items.length === 0
                ? 'Add a client when they approach you to advertise on your kiosks.'
                : 'Try a different search term.'
            }
            action={
              items.length === 0 ? (
                <Button type="button" onClick={() => setModalOpen(true)}>
                  New advertiser
                </Button>
              ) : null
            }
          />
        ) : (
          <table className="table table-clickable">
            <thead>
              <tr>
                <th>Name</th>
                <th>Contact</th>
                <th>Status</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((item) => (
                <tr key={item.id} onClick={() => navigate(`/advertisers/${item.id}`)}>
                  <td>{item.name}</td>
                  <td>{item.contactEmail ?? '—'}</td>
                  <td>
                    <StatusBadge status={item.isActive ? 'active' : 'inactive'} />
                  </td>
                  <td>{formatDate(item.createdAt)}</td>
                  <td>
                    <div className="row-actions">
                      <Button
                        type="button"
                        variant="secondary"
                        onClick={(e) => {
                          e.stopPropagation();
                          navigate(`/advertisers/${item.id}`);
                        }}
                      >
                        View
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        onClick={(e) => void toggleActive(item, e)}
                      >
                        {item.isActive ? 'Deactivate' : 'Activate'}
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>

      <Modal
        open={modalOpen}
        title="New advertiser"
        onClose={() => setModalOpen(false)}
        footer={
          <>
            <Button type="button" variant="ghost" onClick={() => setModalOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" form="create-advertiser-form" disabled={submitting}>
              {submitting ? 'Saving…' : 'Create'}
            </Button>
          </>
        }
      >
        <form id="create-advertiser-form" className="stack" onSubmit={(e) => void onCreate(e)}>
          <label>
            Company / brand name
            <Input value={name} onChange={(e) => setName(e.target.value)} required autoFocus />
          </label>
          <label>
            Contact email (optional)
            <Input
              type="email"
              value={contactEmail}
              onChange={(e) => setContactEmail(e.target.value)}
            />
          </label>
        </form>
      </Modal>
    </div>
  );
}
