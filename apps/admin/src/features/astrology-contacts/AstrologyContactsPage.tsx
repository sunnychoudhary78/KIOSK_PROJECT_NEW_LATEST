import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  EmptyState,
  FilterChips,
  Input,
  PageHeader,
  Panel,
  Select,
  Toolbar,
} from '../../core/ui/primitives';

const KIND_OPTIONS = ['astrologer', 'pandit'] as const;

type AstrologyContactKind = (typeof KIND_OPTIONS)[number];

type AstrologyContact = {
  id: string;
  kind: AstrologyContactKind;
  name: string;
  phone: string;
  rating: number;
  sortOrder: number;
  showNumberClicks: number;
  createdAt: string;
  updatedAt: string;
};

type AstrologyContactList = {
  items: AstrologyContact[];
};

type FormState = {
  kind: AstrologyContactKind;
  name: string;
  phone: string;
  rating: string;
  sortOrder: string;
};

const emptyForm: FormState = {
  kind: 'astrologer',
  name: '',
  phone: '',
  rating: '4.5',
  sortOrder: '',
};

function kindLabel(kind: AstrologyContactKind) {
  return kind === 'astrologer' ? 'Astrologer' : 'Pandit';
}

export function AstrologyContactsPage() {
  const { token } = useAuth();
  const [list, setList] = useState<AstrologyContactList | null>(null);
  const [loading, setLoading] = useState(false);
  const [listError, setListError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [kindFilter, setKindFilter] = useState('all');

  const [form, setForm] = useState<FormState>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [removingId, setRemovingId] = useState<string | null>(null);

  const loadList = useCallback(async () => {
    setLoading(true);
    setListError(null);
    try {
      const result = await apiRequest<AstrologyContactList>('/astrology-contacts', { token });
      setList(result);
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Failed to load astrology contacts');
      setList(null);
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    void loadList();
  }, [loadList]);

  const filtered = useMemo(() => {
    const items = list?.items ?? [];
    const q = search.trim().toLowerCase();
    return items.filter((item) => {
      if (kindFilter !== 'all' && item.kind !== kindFilter) return false;
      if (!q) return true;
      return [item.name, item.phone, kindLabel(item.kind)].join(' ').toLowerCase().includes(q);
    });
  }, [list, search, kindFilter]);

  function startEdit(item: AstrologyContact) {
    setEditingId(item.id);
    setForm({
      kind: item.kind,
      name: item.name,
      phone: item.phone,
      rating: String(item.rating),
      sortOrder: String(item.sortOrder),
    });
    setFormError(null);
  }

  function resetForm() {
    setEditingId(null);
    setForm(emptyForm);
    setFormError(null);
  }

  async function saveContact(event: FormEvent) {
    event.preventDefault();
    setSaving(true);
    setFormError(null);
    const rating = Number(form.rating);
    if (!Number.isFinite(rating) || rating < 0 || rating > 5) {
      setFormError('Rating must be a number from 0 to 5');
      setSaving(false);
      return;
    }
    const body: {
      kind: AstrologyContactKind;
      name: string;
      phone: string;
      rating: number;
      sortOrder?: number;
    } = {
      kind: form.kind,
      name: form.name.trim(),
      phone: form.phone.trim(),
      rating,
    };
    if (form.sortOrder.trim() !== '') {
      body.sortOrder = Number(form.sortOrder);
    }
    try {
      if (editingId) {
        await apiRequest(`/astrology-contacts/${editingId}`, {
          method: 'PUT',
          token,
          body,
        });
      } else {
        await apiRequest('/astrology-contacts', {
          method: 'POST',
          token,
          body,
        });
      }
      resetForm();
      await loadList();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to save contact');
    } finally {
      setSaving(false);
    }
  }

  async function removeContact(item: AstrologyContact) {
    if (
      !window.confirm(
        `Remove “${item.name}” (${item.phone}) from the ${kindLabel(item.kind).toLowerCase()} list?`,
      )
    ) {
      return;
    }
    setRemovingId(item.id);
    setListError(null);
    try {
      await apiRequest(`/astrology-contacts/${item.id}`, { method: 'DELETE', token });
      if (editingId === item.id) {
        resetForm();
      }
      await loadList();
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Failed to remove contact');
    } finally {
      setRemovingId(null);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Astrology contacts"
        subtitle="Astrologers and pandits shown on the kiosk Astrology hub. Citizens dial from their own phone."
      />

      <Panel title={editingId ? 'Edit contact' : 'Add contact'}>
        <form onSubmit={(event) => void saveContact(event)}>
          <div className="settings-row">
            <label>
              Type
              <Select
                value={form.kind}
                onChange={(e) =>
                  setForm((s) => ({ ...s, kind: e.target.value as AstrologyContactKind }))
                }
              >
                {KIND_OPTIONS.map((kind) => (
                  <option key={kind} value={kind}>
                    {kindLabel(kind)}
                  </option>
                ))}
              </Select>
            </label>
            <label>
              Name
              <Input
                value={form.name}
                onChange={(e) => setForm((s) => ({ ...s, name: e.target.value }))}
                placeholder="Pandit Ram Sharma"
                required
              />
            </label>
            <label>
              Phone
              <Input
                value={form.phone}
                onChange={(e) => setForm((s) => ({ ...s, phone: e.target.value }))}
                placeholder="9876543210"
                required
                inputMode="numeric"
                maxLength={10}
              />
            </label>
            <label>
              Rating (0–5)
              <Input
                type="number"
                min={0}
                max={5}
                step={0.5}
                value={form.rating}
                onChange={(e) => setForm((s) => ({ ...s, rating: e.target.value }))}
                required
              />
            </label>
            <label>
              Sort order
              <Input
                type="number"
                min={0}
                value={form.sortOrder}
                onChange={(e) => setForm((s) => ({ ...s, sortOrder: e.target.value }))}
                placeholder="Auto"
              />
            </label>
          </div>
          {formError ? <p className="error">{formError}</p> : null}
          <div className="mt-3 flex flex-wrap gap-2">
            <Button type="submit" disabled={saving}>
              {saving ? 'Saving…' : editingId ? 'Save changes' : 'Add contact'}
            </Button>
            {editingId ? (
              <Button type="button" variant="ghost" onClick={resetForm} disabled={saving}>
                Cancel
              </Button>
            ) : null}
          </div>
        </form>
      </Panel>

      <Panel title="Contacts on kiosks">
        {listError ? <p className="error">{listError}</p> : null}
        {loading && !list ? <p>Loading…</p> : null}
        {!loading && list && list.items.length === 0 ? (
          <EmptyState
            title="No contacts yet"
            description="Add an astrologer or pandit above. Kiosks will show a not-available message until then."
          />
        ) : null}
        {list && list.items.length > 0 ? (
          <>
            <Toolbar
              search={search}
              onSearchChange={setSearch}
              searchPlaceholder="Search name or phone"
            >
              <FilterChips
                options={[
                  { value: 'all', label: 'All' },
                  { value: 'astrologer', label: 'Astrologers' },
                  { value: 'pandit', label: 'Pandits' },
                ]}
                value={kindFilter}
                onChange={setKindFilter}
              />
            </Toolbar>
            {filtered.length === 0 ? (
              <EmptyState title="No matches" description="Adjust filters or search." />
            ) : (
              <table className="table">
                <thead>
                  <tr>
                    <th>Order</th>
                    <th>Type</th>
                    <th>Name</th>
                    <th>Phone</th>
                    <th>Rating</th>
                    <th>Show-number clicks</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((item) => (
                    <tr key={item.id}>
                      <td>{item.sortOrder}</td>
                      <td>{kindLabel(item.kind)}</td>
                      <td className="font-medium">{item.name}</td>
                      <td className="font-mono text-sm">{item.phone}</td>
                      <td>{item.rating.toFixed(1)}</td>
                      <td>{item.showNumberClicks ?? 0}</td>
                      <td className="whitespace-nowrap">
                        <Button
                          type="button"
                          variant="ghost"
                          onClick={() => startEdit(item)}
                          disabled={removingId === item.id}
                        >
                          Edit
                        </Button>
                        <Button
                          type="button"
                          variant="ghost"
                          onClick={() => void removeContact(item)}
                          disabled={removingId === item.id}
                        >
                          {removingId === item.id ? 'Removing…' : 'Remove'}
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </>
        ) : null}
      </Panel>
    </div>
  );
}
