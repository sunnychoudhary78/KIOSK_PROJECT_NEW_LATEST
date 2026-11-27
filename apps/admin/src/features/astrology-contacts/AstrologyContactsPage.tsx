import { useCallback, useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import { Camera } from 'lucide-react';
import { apiRequest, apiRequestBlob, apiUploadFormData } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { config } from '../../core/config';
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
import { adsMediaPath } from '../ads/mediaUrl';

const KIND_OPTIONS = ['astrologer', 'pandit', 'numerology'] as const;

type AstrologyContactKind = (typeof KIND_OPTIONS)[number];

type AstrologyContact = {
  id: string;
  kind: AstrologyContactKind;
  name: string;
  phone: string;
  rating: number;
  sortOrder: number;
  showNumberClicks: number;
  address: string | null;
  degree: string | null;
  experienceYears: number | null;
  photoUrl: string | null;
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
  address: string;
  degree: string;
  experienceYears: string;
};

const emptyForm: FormState = {
  kind: 'astrologer',
  name: '',
  phone: '',
  rating: '4.5',
  sortOrder: '',
  address: '',
  degree: '',
  experienceYears: '',
};

function kindLabel(kind: AstrologyContactKind) {
  if (kind === 'astrologer') return 'Astrologer';
  if (kind === 'pandit') return 'Pandit';
  return 'Numerology';
}

function PhotoThumb({
  photoUrl,
  name,
  token,
}: {
  photoUrl: string | null;
  name: string;
  token: string | null;
}) {
  const [blobUrl, setBlobUrl] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    let objectUrl: string | null = null;
    async function load() {
      setBlobUrl(null);
      if (!photoUrl || !token) return;
      const path = adsMediaPath(photoUrl);
      if (!path) return;
      try {
        const blob = await apiRequestBlob(path, { token });
        if (cancelled) return;
        objectUrl = URL.createObjectURL(blob);
        setBlobUrl(objectUrl);
      } catch {
        if (!cancelled) setBlobUrl(null);
      }
    }
    void load();
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [photoUrl, token]);

  if (blobUrl) {
    return <img src={blobUrl} alt="" className="h-10 w-10 rounded-full object-cover" />;
  }
  return (
    <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-muted text-sm font-semibold">
      {name.slice(0, 1).toUpperCase()}
    </span>
  );
}

export function AstrologyContactsPage() {
  const { token } = useAuth();
  const formPanelRef = useRef<HTMLDivElement | null>(null);
  const [list, setList] = useState<AstrologyContactList | null>(null);
  const [loading, setLoading] = useState(false);
  const [listError, setListError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [kindFilter, setKindFilter] = useState('all');

  const [form, setForm] = useState<FormState>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingPhotoUrl, setEditingPhotoUrl] = useState<string | null>(null);
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
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

  useEffect(() => {
    if (!photoFile) {
      setPhotoPreview(null);
      return;
    }
    const url = URL.createObjectURL(photoFile);
    setPhotoPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [photoFile]);

  useEffect(() => {
    let cancelled = false;
    let objectUrl: string | null = null;
    async function loadExistingPhoto() {
      if (!editingPhotoUrl || !token || photoFile) {
        if (!photoFile) setPhotoPreview(null);
        return;
      }
      const path = adsMediaPath(editingPhotoUrl);
      if (!path) return;
      try {
        const blob = await apiRequestBlob(path, { token });
        if (cancelled) return;
        objectUrl = URL.createObjectURL(blob);
        setPhotoPreview(objectUrl);
      } catch {
        if (!cancelled) setPhotoPreview(null);
      }
    }
    void loadExistingPhoto();
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [editingPhotoUrl, token, photoFile]);

  const filtered = useMemo(() => {
    const items = list?.items ?? [];
    const q = search.trim().toLowerCase();
    return items.filter((item) => {
      if (kindFilter !== 'all' && item.kind !== kindFilter) return false;
      if (!q) return true;
      return [item.name, item.phone, item.address ?? '', item.degree ?? '', kindLabel(item.kind)]
        .join(' ')
        .toLowerCase()
        .includes(q);
    });
  }, [list, search, kindFilter]);

  function startEdit(item: AstrologyContact) {
    setEditingId(item.id);
    setEditingPhotoUrl(item.photoUrl);
    setPhotoFile(null);
    setForm({
      kind: item.kind,
      name: item.name,
      phone: item.phone,
      rating: Number(item.rating).toFixed(1),
      sortOrder: String(item.sortOrder ?? ''),
      address: item.address ?? '',
      degree: item.degree ?? '',
      experienceYears: item.experienceYears != null ? String(item.experienceYears) : '',
    });
    setFormError(null);
    window.setTimeout(() => {
      formPanelRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 50);
  }

  function resetForm() {
    setEditingId(null);
    setEditingPhotoUrl(null);
    setPhotoFile(null);
    setPhotoPreview(null);
    setForm(emptyForm);
    setFormError(null);
  }

  async function saveContact(event: FormEvent) {
    event.preventDefault();
    setSaving(true);
    setFormError(null);
    const rating = Math.round(Number(form.rating) * 10) / 10;
    if (!Number.isFinite(rating) || rating < 0 || rating > 5) {
      setFormError('Rating must be a number from 0 to 5');
      setSaving(false);
      return;
    }
    const phone = form.phone.trim();
    if (!/^\d{10}$/.test(phone)) {
      setFormError('Phone must be a 10-digit mobile number');
      setSaving(false);
      return;
    }
    const body: {
      kind: AstrologyContactKind;
      name: string;
      phone: string;
      rating: number;
      sortOrder?: number;
      address: string | null;
      degree: string | null;
      experienceYears: number | null;
    } = {
      kind: form.kind,
      name: form.name.trim(),
      phone,
      rating,
      address: form.address.trim() || null,
      degree: form.degree.trim() || null,
      experienceYears: null,
    };
    if (form.sortOrder.trim() !== '') {
      const order = Number(form.sortOrder);
      if (!Number.isInteger(order) || order < 0) {
        setFormError('Sort order must be a whole number');
        setSaving(false);
        return;
      }
      body.sortOrder = order;
    }
    if (form.experienceYears.trim() !== '') {
      const years = Number(form.experienceYears);
      if (!Number.isInteger(years) || years < 0 || years > 80) {
        setFormError('Experience must be a whole number from 0 to 80');
        setSaving(false);
        return;
      }
      body.experienceYears = years;
    }
    try {
      let contactId = editingId;
      if (editingId) {
        await apiRequest(`/astrology-contacts/${editingId}`, {
          method: 'PUT',
          token,
          body,
        });
      } else {
        const created = await apiRequest<AstrologyContact>('/astrology-contacts', {
          method: 'POST',
          token,
          body,
        });
        contactId = created.id;
      }
      if (photoFile && contactId) {
        const formData = new FormData();
        formData.append('photo', photoFile);
        await apiUploadFormData(`/astrology-contacts/${contactId}/photo`, {
          token,
          formData,
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
        subtitle="Astrologers, pandits, and numerologists shown on the kiosk Astrology hub. Click Edit on a row, change fields above, then Save changes."
      />

      <div ref={formPanelRef}>
        <Panel title={editingId ? 'Edit contact' : 'Add contact'}>
          {editingId ? (
            <p className="mb-3 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
              Editing contact. Update the fields below, optionally change the photo, then click{' '}
              <strong>Save changes</strong>.
            </p>
          ) : null}
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
                  step={0.1}
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
              <label>
                Degree / qualification
                <Input
                  value={form.degree}
                  onChange={(e) => setForm((s) => ({ ...s, degree: e.target.value }))}
                  placeholder="Jyotish Acharya"
                />
              </label>
              <label>
                Experience (years)
                <Input
                  type="number"
                  min={0}
                  max={80}
                  value={form.experienceYears}
                  onChange={(e) => setForm((s) => ({ ...s, experienceYears: e.target.value }))}
                  placeholder="15"
                />
              </label>
              <label className="sm:col-span-2">
                Address
                <Input
                  value={form.address}
                  onChange={(e) => setForm((s) => ({ ...s, address: e.target.value }))}
                  placeholder="Gaur City 1, Greater Noida"
                />
              </label>
            </div>

            <div className="mt-4 flex items-center gap-3">
              <div className="flex h-16 w-16 items-center justify-center overflow-hidden rounded-xl border border-dashed border-border bg-muted/40">
                {photoPreview ? (
                  <img src={photoPreview} alt="" className="h-full w-full object-cover" />
                ) : (
                  <Camera className="h-5 w-5 text-muted-foreground" />
                )}
              </div>
              <div className="flex flex-col gap-2">
                <label className="inline-flex cursor-pointer">
                  <span className="rounded-md border border-border bg-background px-3 py-1.5 text-sm font-medium hover:bg-muted">
                    {photoPreview ? 'Change photo' : 'Upload photo'}
                  </span>
                  <input
                    type="file"
                    accept="image/*"
                    className="sr-only"
                    onChange={(event) => setPhotoFile(event.target.files?.[0] ?? null)}
                  />
                </label>
                {photoFile ? (
                  <button
                    type="button"
                    className="text-left text-xs text-muted-foreground hover:text-foreground"
                    onClick={() => setPhotoFile(null)}
                  >
                    Clear new photo
                  </button>
                ) : null}
              </div>
            </div>

            {formError ? <p className="error mt-3">{formError}</p> : null}
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
      </div>

      <Panel title="Contacts on kiosks">
        {listError ? <p className="error">{listError}</p> : null}
        {loading && !list ? <p>Loading…</p> : null}
        {!loading && list && list.items.length === 0 ? (
          <EmptyState
            title="No contacts yet"
            description="Add an astrologer, pandit, or numerologist above. Kiosks will show a not-available message until then."
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
                  { value: 'numerology', label: 'Numerology' },
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
                    <th>Photo</th>
                    <th>Order</th>
                    <th>Type</th>
                    <th>Name</th>
                    <th>Phone</th>
                    <th>Degree</th>
                    <th>Exp.</th>
                    <th>Address</th>
                    <th>Rating</th>
                    <th>Clicks</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((item) => (
                    <tr key={item.id}>
                      <td>
                        <PhotoThumb photoUrl={item.photoUrl} name={item.name} token={token} />
                      </td>
                      <td>{item.sortOrder}</td>
                      <td>{kindLabel(item.kind)}</td>
                      <td className="font-medium">{item.name}</td>
                      <td className="font-mono text-sm">{item.phone}</td>
                      <td className="max-w-[8rem] truncate text-sm">{item.degree ?? '—'}</td>
                      <td className="text-sm">
                        {item.experienceYears != null ? `${item.experienceYears}y` : '—'}
                      </td>
                      <td className="max-w-[10rem] truncate text-sm text-muted-foreground">
                        {item.address ?? '—'}
                      </td>
                      <td>{Number(item.rating).toFixed(1)}</td>
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
      <p className="text-xs text-muted-foreground">
        API base: {config.apiBaseUrl}. After saving, reopen the kiosk Astrology contact screen to
        refresh.
      </p>
    </div>
  );
}
