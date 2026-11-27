import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type FormEvent,
  type ReactNode,
} from 'react';
import { Camera, MapPin, Pin, Star } from 'lucide-react';
import { apiRequest, apiRequestBlob, apiUploadFormData } from '../../core/api/client';
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
import { adsMediaPath } from '../ads/mediaUrl';

type LocalContact = {
  id: string;
  name: string;
  phone: string;
  sortOrder: number;
  rating: number;
  topRank: number | null;
  pinned?: boolean;
  showNumberClicks?: number;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  distanceKm?: number | null;
  photoUrl: string | null;
};

const TOP_RANK_OPTIONS = [
  { value: '', label: 'Not in Top 5' },
  { value: '1', label: 'Top 1' },
  { value: '2', label: 'Top 2' },
  { value: '3', label: 'Top 3' },
  { value: '4', label: 'Top 4' },
  { value: '5', label: 'Top 5' },
] as const;

type LocalCategory = {
  id: string;
  slug: string;
  name: string;
  sortOrder: number;
  isActive: boolean;
  contacts: LocalContact[];
};

type LocalList = {
  categories: LocalCategory[];
};

type KioskDevice = {
  id: string;
  name: string;
  siteName: string;
  latitude: number | null;
  longitude: number | null;
};

function formatRating(value: number): string {
  return Number.isFinite(value) ? value.toFixed(1).replace(/\.0$/, '') : '0';
}

function AuthPhoto({
  photoUrl,
  token,
  className,
  fallback,
}: {
  photoUrl: string | null;
  token: string | null;
  className?: string;
  fallback: ReactNode;
}) {
  const [src, setSrc] = useState<string | null>(null);
  const path = adsMediaPath(photoUrl);

  useEffect(() => {
    if (!path || !token) {
      setSrc(null);
      return;
    }
    let cancelled = false;
    let objectUrl: string | null = null;
    void (async () => {
      try {
        const blob = await apiRequestBlob(path, { token });
        if (cancelled) return;
        objectUrl = URL.createObjectURL(blob);
        setSrc(objectUrl);
      } catch {
        if (!cancelled) setSrc(null);
      }
    })();
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [path, token]);

  if (!src) return <>{fallback}</>;
  return <img src={src} alt="" className={className} />;
}

function StarRatingInput({
  value,
  onChange,
}: {
  value: number;
  onChange: (next: number) => void;
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <span className="text-sm font-medium">Rating</span>
      <div className="flex items-center gap-1">
        {[1, 2, 3, 4, 5].map((star) => {
          const active = value >= star;
          const half = !active && value >= star - 0.5;
          return (
            <button
              key={star}
              type="button"
              className="rounded p-0.5 text-amber-400 transition hover:scale-110"
              title={`${star}`}
              onClick={() => onChange(value === star ? star - 0.5 : star)}
            >
              <Star
                className={`h-5 w-5 ${
                  active ? 'fill-amber-400 text-amber-400' : half ? 'fill-amber-200 text-amber-400' : 'text-muted-foreground/40'
                }`}
              />
            </button>
          );
        })}
        <span className="ml-2 text-sm tabular-nums text-muted-foreground">
          {formatRating(value)} / 5
        </span>
      </div>
    </div>
  );
}

function PhotoPicker({
  file,
  previewUrl,
  onFile,
  onClearPreview,
  label = 'Photo (optional)',
}: {
  file: File | null;
  previewUrl?: string | null;
  onFile: (file: File | null) => void;
  onClearPreview?: () => void;
  label?: string;
}) {
  const localPreview = useMemo(
    () => (file ? URL.createObjectURL(file) : null),
    [file],
  );

  useEffect(() => {
    return () => {
      if (localPreview) URL.revokeObjectURL(localPreview);
    };
  }, [localPreview]);

  const shown = localPreview ?? previewUrl ?? null;

  return (
    <div className="flex flex-col gap-1.5">
      <span className="text-sm font-medium">{label}</span>
      <div className="flex items-center gap-3">
        <div className="flex h-16 w-16 items-center justify-center overflow-hidden rounded-xl border border-dashed border-border bg-muted/40">
          {shown ? (
            <img src={shown} alt="" className="h-full w-full object-cover" />
          ) : (
            <Camera className="h-5 w-5 text-muted-foreground" />
          )}
        </div>
        <div className="flex flex-col gap-2">
          <label className="inline-flex cursor-pointer">
            <span className="rounded-md border border-border bg-background px-3 py-1.5 text-sm font-medium hover:bg-muted">
              {shown ? 'Change photo' : 'Upload photo'}
            </span>
            <input
              type="file"
              accept="image/*"
              className="sr-only"
              onChange={(event) => onFile(event.target.files?.[0] ?? null)}
            />
          </label>
          {shown ? (
            <button
              type="button"
              className="text-left text-xs text-muted-foreground hover:text-foreground"
              onClick={() => {
                onFile(null);
                onClearPreview?.();
              }}
            >
              Remove photo
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}

export function FindServicesPage() {
  const { token } = useAuth();
  const [list, setList] = useState<LocalList | null>(null);
  const [loading, setLoading] = useState(false);
  const [listError, setListError] = useState<string | null>(null);
  const [serviceName, setServiceName] = useState('');
  const [savingService, setSavingService] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [statusSavingId, setStatusSavingId] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [contactName, setContactName] = useState('');
  const [contactPhone, setContactPhone] = useState('');
  const [contactRating, setContactRating] = useState(0);
  const [contactTopRank, setContactTopRank] = useState<number | null>(null);
  const [contactAddress, setContactAddress] = useState('');
  const [contactLat, setContactLat] = useState('');
  const [contactLng, setContactLng] = useState('');
  const [contactPhotoFile, setContactPhotoFile] = useState<File | null>(null);
  const [savingContact, setSavingContact] = useState(false);
  const [contactError, setContactError] = useState<string | null>(null);
  const [removingContactId, setRemovingContactId] = useState<string | null>(null);
  const [serviceSearch, setServiceSearch] = useState('');
  const [contactSearch, setContactSearch] = useState('');
  const [editContact, setEditContact] = useState<LocalContact | null>(null);
  const [editName, setEditName] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editRating, setEditRating] = useState(0);
  const [editTopRank, setEditTopRank] = useState<number | null>(null);
  const [editAddress, setEditAddress] = useState('');
  const [editLat, setEditLat] = useState('');
  const [editLng, setEditLng] = useState('');
  const [editPhotoFile, setEditPhotoFile] = useState<File | null>(null);
  const [editClearPhoto, setEditClearPhoto] = useState(false);
  const [editSaving, setEditSaving] = useState(false);
  const [editError, setEditError] = useState<string | null>(null);
  const [editPhotoPreview, setEditPhotoPreview] = useState<string | null>(null);
  const [kiosks, setKiosks] = useState<KioskDevice[]>([]);

  const loadList = useCallback(async () => {
    setLoading(true);
    setListError(null);
    try {
      const result = await apiRequest<LocalList>('/local-services', { token });
      setList(result);
      setSelectedId((current) => {
        if (current && result.categories.some((item) => item.id === current)) return current;
        return result.categories[0]?.id ?? null;
      });
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Failed to load services');
      setList(null);
    } finally {
      setLoading(false);
    }
  }, [token]);

  const loadKiosks = useCallback(async () => {
    if (!token) {
      setKiosks([]);
      return;
    }
    try {
      const result = await apiRequest<{ items: KioskDevice[] }>('/devices', { token });
      setKiosks(
        (result.items ?? []).filter(
          (item) => item.latitude != null && item.longitude != null,
        ),
      );
    } catch {
      setKiosks([]);
    }
  }, [token]);

  useEffect(() => {
    void loadList();
    void loadKiosks();
  }, [loadList, loadKiosks]);

  const selected = list?.categories.find((item) => item.id === selectedId) ?? null;

  const filteredServices = useMemo(() => {
    const categories = list?.categories ?? [];
    const q = serviceSearch.trim().toLowerCase();
    if (!q) return categories;
    return categories.filter((item) =>
      [item.name, item.slug, String(item.contacts.length)].join(' ').toLowerCase().includes(q),
    );
  }, [list, serviceSearch]);

  const filteredContacts = useMemo(() => {
    const contacts = selected?.contacts ?? [];
    const q = contactSearch.trim().toLowerCase();
    if (!q) return contacts;
    return contacts.filter((item) =>
      [item.name, item.phone, item.address ?? '', String(item.rating)]
        .join(' ')
        .toLowerCase()
        .includes(q),
    );
  }, [selected, contactSearch]);

  function resetContactForm() {
    setContactName('');
    setContactPhone('');
    setContactRating(0);
    setContactTopRank(null);
    setContactAddress('');
    setContactLat('');
    setContactLng('');
    setContactPhotoFile(null);
  }

  function parseOptionalCoord(raw: string): number | null {
    const trimmed = raw.trim();
    if (!trimmed) return null;
    // Allow paste of "28.65195, 77.23149" into one field — take the first number.
    const first = trimmed.split(/[,/\s]+/).find((part) => part.length > 0) ?? trimmed;
    const value = Number(first);
    return Number.isFinite(value) ? value : Number.NaN;
  }

  function applyKioskPin(
    deviceId: string,
    setLat: (value: string) => void,
    setLng: (value: string) => void,
  ) {
    const device = kiosks.find((item) => item.id === deviceId);
    if (!device || device.latitude == null || device.longitude == null) return;
    setLat(String(device.latitude));
    setLng(String(device.longitude));
  }

  const kioskPinOptions = useMemo(
    () =>
      kiosks.map((item) => ({
        id: item.id,
        label: `${item.name} · ${item.siteName} (${item.latitude!.toFixed(5)}, ${item.longitude!.toFixed(5)})`,
      })),
    [kiosks],
  );

  async function addService(event: FormEvent) {
    event.preventDefault();
    setSavingService(true);
    setFormError(null);
    try {
      const created = await apiRequest<LocalCategory>('/local-services', {
        method: 'POST',
        token,
        body: { name: serviceName.trim() },
      });
      setServiceName('');
      await loadList();
      setSelectedId(created.id);
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to add service');
    } finally {
      setSavingService(false);
    }
  }

  async function setServiceActive(item: LocalCategory, isActive: boolean) {
    if (!isActive) {
      const ok = window.confirm(
        `Set “${item.name}” inactive? It will hide from kiosks until you activate it again.`,
      );
      if (!ok) return;
    }
    setStatusSavingId(item.id);
    setListError(null);
    try {
      await apiRequest(`/local-services/${item.id}/status`, {
        method: 'PATCH',
        token,
        body: { isActive },
      });
      await loadList();
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Failed to update service status');
    } finally {
      setStatusSavingId(null);
    }
  }

  async function addContact(event: FormEvent) {
    event.preventDefault();
    if (!selected) return;
    const latitude = parseOptionalCoord(contactLat);
    const longitude = parseOptionalCoord(contactLng);
    if (Number.isNaN(latitude) || Number.isNaN(longitude)) {
      setContactError('Latitude and longitude must be valid numbers');
      return;
    }
    if ((latitude == null) !== (longitude == null)) {
      setContactError('Set both latitude and longitude (required for kiosk nearby filtering)');
      return;
    }
    setSavingContact(true);
    setContactError(null);
    try {
      const created = await apiRequest<LocalContact>(`/local-services/${selected.id}/contacts`, {
        method: 'POST',
        token,
        body: {
          name: contactName.trim(),
          phone: contactPhone.trim(),
          rating: contactRating,
          topRank: contactTopRank,
          address: contactAddress.trim() || null,
          latitude,
          longitude,
        },
      });
      if (contactPhotoFile) {
        const form = new FormData();
        form.append('photo', contactPhotoFile);
        await apiUploadFormData(`/local-services/${selected.id}/contacts/${created.id}/photo`, {
          token,
          formData: form,
        });
      }
      resetContactForm();
      await loadList();
    } catch (err) {
      setContactError(err instanceof Error ? err.message : 'Failed to add number');
    } finally {
      setSavingContact(false);
    }
  }

  function openEdit(contact: LocalContact) {
    setEditContact(contact);
    setEditName(contact.name);
    setEditPhone(contact.phone);
    setEditRating(contact.rating ?? 0);
    setEditTopRank(contact.topRank ?? null);
    setEditAddress(contact.address ?? '');
    setEditLat(contact.latitude != null ? String(contact.latitude) : '');
    setEditLng(contact.longitude != null ? String(contact.longitude) : '');
    setEditPhotoFile(null);
    setEditClearPhoto(false);
    setEditPhotoPreview(null);
    setEditError(null);
  }

  useEffect(() => {
    if (!editContact?.photoUrl || !token || editClearPhoto) {
      setEditPhotoPreview(null);
      return;
    }
    const path = adsMediaPath(editContact.photoUrl);
    if (!path) return;
    let cancelled = false;
    let objectUrl: string | null = null;
    void (async () => {
      try {
        const blob = await apiRequestBlob(path, { token });
        if (cancelled) return;
        objectUrl = URL.createObjectURL(blob);
        setEditPhotoPreview(objectUrl);
      } catch {
        if (!cancelled) setEditPhotoPreview(null);
      }
    })();
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [editContact?.id, editContact?.photoUrl, editClearPhoto, token]);

  async function saveEdit(event: FormEvent) {
    event.preventDefault();
    if (!selected || !editContact) return;
    const latitude = parseOptionalCoord(editLat);
    const longitude = parseOptionalCoord(editLng);
    if (Number.isNaN(latitude) || Number.isNaN(longitude)) {
      setEditError('Latitude and longitude must be valid numbers');
      return;
    }
    if ((latitude == null) !== (longitude == null)) {
      setEditError('Set both latitude and longitude (or clear both)');
      return;
    }
    setEditSaving(true);
    setEditError(null);
    try {
      await apiRequest(`/local-services/${selected.id}/contacts/${editContact.id}`, {
        method: 'PATCH',
        token,
        body: {
          name: editName.trim(),
          phone: editPhone.trim(),
          rating: editRating,
          topRank: editTopRank,
          address: editAddress.trim() || null,
          latitude,
          longitude,
          clearPhoto: editClearPhoto && !editPhotoFile ? true : undefined,
        },
      });
      if (editPhotoFile) {
        const form = new FormData();
        form.append('photo', editPhotoFile);
        await apiUploadFormData(`/local-services/${selected.id}/contacts/${editContact.id}/photo`, {
          token,
          formData: form,
        });
      }
      setEditContact(null);
      await loadList();
    } catch (err) {
      setEditError(err instanceof Error ? err.message : 'Failed to save contact');
    } finally {
      setEditSaving(false);
    }
  }

  async function removeContact(contact: LocalContact) {
    if (!selected) return;
    if (!window.confirm(`Remove “${contact.name}” (${contact.phone}) from ${selected.name}?`)) {
      return;
    }
    setRemovingContactId(contact.id);
    setContactError(null);
    try {
      await apiRequest(`/local-services/${selected.id}/contacts/${contact.id}`, {
        method: 'DELETE',
        token,
      });
      await loadList();
    } catch (err) {
      setContactError(err instanceof Error ? err.message : 'Failed to remove number');
    } finally {
      setRemovingContactId(null);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Find services"
        subtitle="Copy lat/lng from the target kiosk so distance shows 0 km. Lat/lng is required on kiosk; pins up to 50 km still appear after nearby ones."
      />

      <div className="grid gap-6 xl:grid-cols-[minmax(0,18rem)_minmax(0,1fr)]">
        {/* Left: services list */}
        <Panel title="Services">
          <form
            className="mb-4 flex gap-2"
            onSubmit={(event) => void addService(event)}
          >
            <Input
              value={serviceName}
              onChange={(event) => setServiceName(event.target.value)}
              placeholder="New service name"
              required
              className="flex-1"
            />
            <Button type="submit" disabled={savingService}>
              {savingService ? '…' : 'Add'}
            </Button>
          </form>
          {formError ? <p className="error mb-3">{formError}</p> : null}
          {listError ? <p className="error mb-3">{listError}</p> : null}

          <Toolbar
            search={serviceSearch}
            onSearchChange={setServiceSearch}
            searchPlaceholder="Search services"
          />

          {loading && !list ? <p className="text-sm text-muted-foreground">Loading…</p> : null}
          {!loading && list && list.categories.length === 0 ? (
            <EmptyState title="No services" description="Add a trade above." />
          ) : null}
          {filteredServices.length === 0 && list && list.categories.length > 0 ? (
            <EmptyState title="No matches" description="Try a different search." />
          ) : null}

          <ul className="mt-2 space-y-1">
            {filteredServices.map((item) => {
              const selected = item.id === selectedId;
              const isActive = item.isActive !== false;
              return (
                <li key={item.id}>
                  <div
                    className={`flex items-center gap-2 rounded-lg border px-3 py-2.5 transition ${
                      selected
                        ? 'border-primary/40 bg-primary/5 shadow-sm'
                        : 'border-transparent hover:border-border hover:bg-muted/50'
                    } ${!isActive ? 'opacity-70' : ''}`}
                  >
                    <button
                      type="button"
                      onClick={() => {
                        setSelectedId(item.id);
                        setContactError(null);
                      }}
                      className="min-w-0 flex-1 text-left"
                    >
                      <div className="flex items-center gap-2">
                        <span className="truncate text-sm font-semibold">{item.name}</span>
                        <StatusBadge status={isActive ? 'active' : 'inactive'} />
                      </div>
                      <div className="text-xs text-muted-foreground">
                        {item.contacts.length}{' '}
                        {item.contacts.length === 1 ? 'number' : 'numbers'}
                      </div>
                    </button>
                    {isActive ? (
                      <Button
                        type="button"
                        variant="danger"
                        className="h-7 shrink-0 px-2 text-xs"
                        disabled={statusSavingId === item.id}
                        onClick={() => void setServiceActive(item, false)}
                      >
                        {statusSavingId === item.id ? '…' : 'Inactive'}
                      </Button>
                    ) : (
                      <Button
                        type="button"
                        variant="secondary"
                        className="h-7 shrink-0 px-2 text-xs"
                        disabled={statusSavingId === item.id}
                        onClick={() => void setServiceActive(item, true)}
                      >
                        {statusSavingId === item.id ? '…' : 'Active'}
                      </Button>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        </Panel>

        {/* Right: contacts for selected service */}
        <div className="space-y-6">
          {!selected ? (
            <Panel title="Providers">
              <EmptyState
                title="Select a service"
                description="Choose a service on the left to manage its providers."
              />
            </Panel>
          ) : (
            <>
              <Panel title={`Add provider · ${selected.name}`}>
                <form className="space-y-4" onSubmit={(event) => void addContact(event)}>
                  <div className="grid gap-4 sm:grid-cols-2">
                    <label className="flex flex-col gap-1.5 text-sm font-medium">
                      Name
                      <Input
                        value={contactName}
                        onChange={(event) => setContactName(event.target.value)}
                        placeholder="Ravi Sharma"
                        required
                      />
                    </label>
                    <label className="flex flex-col gap-1.5 text-sm font-medium">
                      Phone (10 digits)
                      <Input
                        value={contactPhone}
                        onChange={(event) => setContactPhone(event.target.value)}
                        placeholder="9876543210"
                        inputMode="numeric"
                        pattern="[0-9]{10}"
                        required
                      />
                    </label>
                    <label className="flex flex-col gap-1.5 text-sm font-medium sm:col-span-2">
                      Address
                      <Input
                        value={contactAddress}
                        onChange={(event) => setContactAddress(event.target.value)}
                        placeholder="Shop 12, Main Market"
                      />
                    </label>
                    <label className="flex flex-col gap-1.5 text-sm font-medium">
                      Latitude
                      <Input
                        value={contactLat}
                        onChange={(event) => setContactLat(event.target.value)}
                        placeholder="28.613900"
                        inputMode="decimal"
                      />
                    </label>
                    <label className="flex flex-col gap-1.5 text-sm font-medium">
                      Longitude
                      <Input
                        value={contactLng}
                        onChange={(event) => setContactLng(event.target.value)}
                        placeholder="77.209000"
                        inputMode="decimal"
                      />
                    </label>
                  </div>
                  {kioskPinOptions.length > 0 ? (
                    <label className="flex flex-col gap-1.5 text-sm font-medium">
                      Copy location from kiosk
                      <select
                        className="h-10 rounded-md border border-border bg-background px-3 text-sm"
                        defaultValue=""
                        onChange={(event) => {
                          applyKioskPin(event.target.value, setContactLat, setContactLng);
                          event.target.value = '';
                        }}
                      >
                        <option value="" disabled>
                          Select kiosk to copy exact lat/lng…
                        </option>
                        {kioskPinOptions.map((item) => (
                          <option key={item.id} value={item.id}>
                            {item.label}
                          </option>
                        ))}
                      </select>
                    </label>
                  ) : null}
                  <p className="text-xs text-muted-foreground">
                    Use Copy location from kiosk for the machine that should show this provider
                    (same pin = 0 km). Empty lat/lng hides the provider on kiosk; pins up to 50 km
                    still appear after nearby.
                  </p>

                  <div className="grid gap-4 sm:grid-cols-2">
                    <StarRatingInput value={contactRating} onChange={setContactRating} />
                    <PhotoPicker
                      file={contactPhotoFile}
                      onFile={setContactPhotoFile}
                    />
                  </div>

                  <label className="flex flex-col gap-1.5 text-sm font-medium">
                    <span className="inline-flex items-center gap-1.5">
                      <Pin className="h-3.5 w-3.5 text-amber-600" />
                      Top 5 on kiosk
                    </span>
                    <select
                      className="h-10 rounded-md border border-border bg-background px-3 text-sm"
                      value={contactTopRank == null ? '' : String(contactTopRank)}
                      onChange={(event) => {
                        const raw = event.target.value;
                        setContactTopRank(raw === '' ? null : Number(raw));
                      }}
                    >
                      {TOP_RANK_OPTIONS.map((option) => (
                        <option key={option.value || 'none'} value={option.value}>
                          {option.label}
                        </option>
                      ))}
                    </select>
                  </label>

                  {contactError ? <p className="error">{contactError}</p> : null}

                  <div className="flex justify-end">
                    <Button type="submit" disabled={savingContact}>
                      {savingContact ? 'Adding…' : 'Add provider'}
                    </Button>
                  </div>
                </form>
              </Panel>

              <Panel title={`Providers on kiosk · ${selected.name}`}>
                <p className="mb-3 text-xs text-muted-foreground">
                  Order on kiosk: Top 1–5 first, then distance, then rating.
                </p>
                {selected.contacts.length === 0 ? (
                  <EmptyState
                    title="No providers yet"
                    description="Add a name, phone, rating, address, and optional photo above."
                  />
                ) : (
                  <>
                    <Toolbar
                      search={contactSearch}
                      onSearchChange={setContactSearch}
                      searchPlaceholder="Search name, phone, address"
                    />
                    {filteredContacts.length === 0 ? (
                      <EmptyState title="No matches" description="Try a different search." />
                    ) : (
                      <ul className="mt-3 space-y-3">
                        {filteredContacts.map((contact) => (
                          <li
                            key={contact.id}
                            className={`flex flex-col gap-3 rounded-xl border p-3 sm:flex-row sm:items-center sm:justify-between ${
                              contact.topRank != null
                                ? 'border-amber-300/80 bg-amber-50/50'
                                : 'border-border bg-background'
                            }`}
                          >
                            <div className="flex min-w-0 items-start gap-3">
                              <AuthPhoto
                                photoUrl={contact.photoUrl}
                                token={token}
                                className="h-14 w-14 shrink-0 rounded-xl object-cover"
                                fallback={
                                  <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-xl bg-muted text-base font-semibold text-muted-foreground">
                                    {contact.name.slice(0, 1).toUpperCase()}
                                  </div>
                                }
                              />
                              <div className="min-w-0 space-y-1">
                                <div className="flex flex-wrap items-center gap-2">
                                  <span className="truncate font-semibold">{contact.name}</span>
                                  {contact.topRank != null ? (
                                    <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-medium text-amber-800">
                                      <Pin className="h-3 w-3" />
                                      Top {contact.topRank}
                                    </span>
                                  ) : null}
                                  <span className="inline-flex items-center gap-1 rounded-full bg-orange-50 px-2 py-0.5 text-[11px] font-semibold text-orange-700">
                                    <Star className="h-3 w-3 fill-amber-400 text-amber-400" />
                                    {formatRating(contact.rating)}
                                  </span>
                                  <span
                                    className="inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-[11px] font-semibold tabular-nums text-slate-700"
                                    title="Show number taps on kiosk"
                                  >
                                    {contact.showNumberClicks ?? 0} clicks
                                  </span>
                                </div>
                                <div className="font-mono text-sm text-foreground">
                                  {contact.phone}
                                </div>
                                {contact.address ? (
                                  <div className="flex items-start gap-1 text-xs text-muted-foreground">
                                    <MapPin className="mt-0.5 h-3 w-3 shrink-0" />
                                    <span className="line-clamp-2">{contact.address}</span>
                                  </div>
                                ) : null}
                                {contact.latitude != null && contact.longitude != null ? (
                                  <div className="text-[11px] tabular-nums text-muted-foreground">
                                    {contact.latitude.toFixed(5)}, {contact.longitude.toFixed(5)}
                                  </div>
                                ) : (
                                  <div className="text-[11px] font-medium text-amber-700">
                                    No map location — hidden on kiosk until lat/lng are set
                                  </div>
                                )}
                              </div>
                            </div>
                            <div className="flex shrink-0 gap-2 self-end sm:self-center">
                              <Button
                                type="button"
                                variant="secondary"
                                onClick={() => openEdit(contact)}
                              >
                                Edit
                              </Button>
                              <Button
                                type="button"
                                variant="ghost"
                                disabled={removingContactId === contact.id}
                                onClick={() => void removeContact(contact)}
                              >
                                {removingContactId === contact.id ? 'Removing…' : 'Remove'}
                              </Button>
                            </div>
                          </li>
                        ))}
                      </ul>
                    )}
                  </>
                )}
              </Panel>
            </>
          )}
        </div>
      </div>

      <Modal
        open={editContact != null}
        title={editContact ? `Edit · ${editContact.name}` : 'Edit provider'}
        description="Pinned stays on top. Highest rating follows. Photo is optional."
        onClose={() => {
          if (!editSaving) setEditContact(null);
        }}
        footer={
          <>
            <Button
              type="button"
              variant="ghost"
              disabled={editSaving}
              onClick={() => setEditContact(null)}
            >
              Cancel
            </Button>
            <Button type="submit" form="edit-local-contact-form" disabled={editSaving}>
              {editSaving ? 'Saving…' : 'Save changes'}
            </Button>
          </>
        }
      >
        {editContact ? (
          <form
            id="edit-local-contact-form"
            className="space-y-4"
            onSubmit={(event) => void saveEdit(event)}
          >
            <div className="grid gap-4 sm:grid-cols-2">
              <label className="flex flex-col gap-1.5 text-sm font-medium">
                Name
                <Input
                  value={editName}
                  onChange={(event) => setEditName(event.target.value)}
                  required
                />
              </label>
              <label className="flex flex-col gap-1.5 text-sm font-medium">
                Phone
                <Input
                  value={editPhone}
                  onChange={(event) => setEditPhone(event.target.value)}
                  inputMode="numeric"
                  pattern="[0-9]{10}"
                  required
                />
              </label>
              <label className="flex flex-col gap-1.5 text-sm font-medium sm:col-span-2">
                Address
                <Input
                  value={editAddress}
                  onChange={(event) => setEditAddress(event.target.value)}
                  placeholder="Shop 12, Main Market"
                />
              </label>
              <label className="flex flex-col gap-1.5 text-sm font-medium">
                Latitude
                <Input
                  value={editLat}
                  onChange={(event) => setEditLat(event.target.value)}
                  placeholder="28.613900"
                  inputMode="decimal"
                />
              </label>
              <label className="flex flex-col gap-1.5 text-sm font-medium">
                Longitude
                <Input
                  value={editLng}
                  onChange={(event) => setEditLng(event.target.value)}
                  placeholder="77.209000"
                  inputMode="decimal"
                />
              </label>
            </div>
            {kioskPinOptions.length > 0 ? (
              <label className="flex flex-col gap-1.5 text-sm font-medium">
                Copy location from kiosk
                <select
                  className="h-10 rounded-md border border-border bg-background px-3 text-sm"
                  defaultValue=""
                  onChange={(event) => {
                    applyKioskPin(event.target.value, setEditLat, setEditLng);
                    event.target.value = '';
                  }}
                >
                  <option value="" disabled>
                    Select kiosk to copy exact lat/lng…
                  </option>
                  {kioskPinOptions.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.label}
                    </option>
                  ))}
                </select>
              </label>
            ) : null}

            <div className="grid gap-4 sm:grid-cols-2">
              <StarRatingInput value={editRating} onChange={setEditRating} />
              <PhotoPicker
                file={editPhotoFile}
                previewUrl={editClearPhoto ? null : editPhotoPreview}
                onFile={(file) => {
                  setEditPhotoFile(file);
                  if (file) setEditClearPhoto(false);
                }}
                onClearPreview={() => setEditClearPhoto(true)}
              />
            </div>

            <label className="flex flex-col gap-1.5 text-sm font-medium">
              <span className="inline-flex items-center gap-1.5">
                <Pin className="h-3.5 w-3.5 text-amber-600" />
                Top 5 on kiosk
              </span>
              <select
                className="h-10 rounded-md border border-border bg-background px-3 text-sm"
                value={editTopRank == null ? '' : String(editTopRank)}
                onChange={(event) => {
                  const raw = event.target.value;
                  setEditTopRank(raw === '' ? null : Number(raw));
                }}
              >
                {TOP_RANK_OPTIONS.map((option) => (
                  <option key={option.value || 'none'} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </label>

            {editError ? <p className="error">{editError}</p> : null}
          </form>
        ) : null}
      </Modal>
    </div>
  );
}
