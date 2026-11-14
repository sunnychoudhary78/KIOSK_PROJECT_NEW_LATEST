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

const ICON_OPTIONS = [
  'sos',
  'police',
  'fire',
  'ambulance',
  'women',
  'child',
  'disaster',
  'phone',
] as const;

type EmergencyIcon = (typeof ICON_OPTIONS)[number];

type EmergencyContact = {
  id: string;
  name: string;
  phone: string;
  icon: EmergencyIcon | string;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
};

type EmergencyList = {
  items: EmergencyContact[];
};

type FormState = {
  name: string;
  phone: string;
  icon: EmergencyIcon;
  sortOrder: string;
};

const emptyForm: FormState = {
  name: '',
  phone: '',
  icon: 'phone',
  sortOrder: '',
};

export function EmergencyContactsPage() {
  const { token } = useAuth();
  const [list, setList] = useState<EmergencyList | null>(null);
  const [loading, setLoading] = useState(false);
  const [listError, setListError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [iconFilter, setIconFilter] = useState('all');

  const [form, setForm] = useState<FormState>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [removingId, setRemovingId] = useState<string | null>(null);

  const loadList = useCallback(async () => {
    setLoading(true);
    setListError(null);
    try {
      const result = await apiRequest<EmergencyList>('/emergency-contacts', { token });
      setList(result);
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Failed to load emergency contacts');
      setList(null);
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    void loadList();
  }, [loadList]);

  const iconOptions = useMemo(() => {
    const values = Array.from(
      new Set((list?.items ?? []).map((item) => item.icon).filter(Boolean)),
    ).sort();
    return [
      { value: 'all', label: 'All icons' },
      ...values.map((icon) => ({ value: icon, label: icon })),
    ];
  }, [list]);

  const filtered = useMemo(() => {
    const items = list?.items ?? [];
    const q = search.trim().toLowerCase();
    return items.filter((item) => {
      if (iconFilter !== 'all' && item.icon !== iconFilter) return false;
      if (!q) return true;
      return [item.name, item.phone, item.icon].join(' ').toLowerCase().includes(q);
    });
  }, [list, search, iconFilter]);

  function startEdit(item: EmergencyContact) {
    setEditingId(item.id);
    setForm({
      name: item.name,
      phone: item.phone,
      icon: (ICON_OPTIONS.includes(item.icon as EmergencyIcon)
        ? item.icon
        : 'phone') as EmergencyIcon,
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
    const body: {
      name: string;
      phone: string;
      icon: EmergencyIcon;
      sortOrder?: number;
    } = {
      name: form.name.trim(),
      phone: form.phone.trim(),
      icon: form.icon,
    };
    if (form.sortOrder.trim() !== '') {
      body.sortOrder = Number(form.sortOrder);
    }
    try {
      if (editingId) {
        await apiRequest(`/emergency-contacts/${editingId}`, {
          method: 'PUT',
          token,
          body,
        });
      } else {
        await apiRequest('/emergency-contacts', {
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

  async function removeContact(item: EmergencyContact) {
    if (!window.confirm(`Remove “${item.name}” (${item.phone}) from the kiosk emergency list?`)) {
      return;
    }
    setRemovingId(item.id);
    setListError(null);
    try {
      await apiRequest(`/emergency-contacts/${item.id}`, { method: 'DELETE', token });
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
        title="Emergency helplines"
        subtitle="Numbers shown on every kiosk Emergency screen. Citizens dial from their own phone."
      />

      <Panel title={editingId ? 'Edit contact' : 'Add contact'}>
        <form onSubmit={(event) => void saveContact(event)}>
          <div className="settings-row">
            <label>
              Name
              <Input
                value={form.name}
                onChange={(e) => setForm((s) => ({ ...s, name: e.target.value }))}
                placeholder="Police"
                required
              />
            </label>
            <label>
              Phone
              <Input
                value={form.phone}
                onChange={(e) => setForm((s) => ({ ...s, phone: e.target.value }))}
                placeholder="112"
                required
              />
            </label>
            <label>
              Icon
              <Select
                value={form.icon}
                onChange={(e) =>
                  setForm((s) => ({ ...s, icon: e.target.value as EmergencyIcon }))
                }
              >
                {ICON_OPTIONS.map((icon) => (
                  <option key={icon} value={icon}>
                    {icon}
                  </option>
                ))}
              </Select>
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
          <EmptyState title="No contacts" description="Add a helpline above." />
        ) : null}
        {list && list.items.length > 0 ? (
          <>
            <Toolbar
              search={search}
              onSearchChange={setSearch}
              searchPlaceholder="Search name or phone"
            >
              <FilterChips
                options={iconOptions}
                value={iconFilter}
                onChange={setIconFilter}
              />
            </Toolbar>
            {filtered.length === 0 ? (
              <EmptyState title="No matches" description="Adjust filters or search." />
            ) : (
              <table className="table">
                <thead>
                  <tr>
                    <th>Order</th>
                    <th>Name</th>
                    <th>Phone</th>
                    <th>Icon</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((item) => (
                    <tr key={item.id}>
                      <td>{item.sortOrder}</td>
                      <td className="font-medium">{item.name}</td>
                      <td className="font-mono text-sm">{item.phone}</td>
                      <td>{item.icon}</td>
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
