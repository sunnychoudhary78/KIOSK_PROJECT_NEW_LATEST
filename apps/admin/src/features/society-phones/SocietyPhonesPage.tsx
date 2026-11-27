import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, EmptyState, Input, PageHeader, Panel, Select } from '../../core/ui/primitives';

type QuotaPeriod = 'daily' | 'weekly' | 'monthly';

type FreeQuotaForm = {
  period: QuotaPeriod;
  freePages: number | '';
  freeBwPages: number | '';
  freeColorPages: number | '';
  combined?: boolean;
};

type SocietyPhone = {
  id: string;
  phone: string;
  name: string;
  societyName: string;
  createdAt: string;
};

type SocietyList = {
  total: number;
  items: SocietyPhone[];
};

type ImportResult = {
  added: number;
  duplicate: number;
  invalidCount: number;
  invalid: Array<{ row: number; value: string; reason: string }>;
};

type PlatformSetting = {
  settingKey: string;
  settingValue: FreeQuotaForm;
};

const DEFAULT_QUOTA: FreeQuotaForm = {
  period: 'daily',
  freePages: 5,
  freeBwPages: 5,
  freeColorPages: 5,
  combined: true,
};

function combinedFreePages(value: FreeQuotaForm): number {
  if (value.freePages !== '' && value.freePages != null) {
    return Math.max(0, Math.min(500, Number(value.freePages) || 0));
  }
  const bw = typeof value.freeBwPages === 'number' ? value.freeBwPages : 0;
  const color = typeof value.freeColorPages === 'number' ? value.freeColorPages : 0;
  const sum = bw + color;
  return sum > 0 ? Math.max(0, Math.min(500, sum)) : 5;
}

type SocietyPhonesPageProps = {
  /** Hide page chrome when nested inside Free Print hub */
  embedded?: boolean;
  /** When false, quota editor is omitted (hub Limits tab owns it) */
  showQuota?: boolean;
};

export function SocietyPhonesPage({
  embedded = false,
  showQuota = true,
}: SocietyPhonesPageProps = {}) {
  const { token } = useAuth();
  const [quota, setQuota] = useState<FreeQuotaForm>(DEFAULT_QUOTA);
  const [quotaError, setQuotaError] = useState<string | null>(null);
  const [quotaSaved, setQuotaSaved] = useState<string | null>(null);
  const [savingQuota, setSavingQuota] = useState(false);

  const [phone, setPhone] = useState('');
  const [name, setName] = useState('');
  const [societyName, setSocietyName] = useState('');
  const [addError, setAddError] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);

  const [file, setFile] = useState<File | null>(null);
  const [fileKey, setFileKey] = useState(0);
  const [importing, setImporting] = useState(false);
  const [importError, setImportError] = useState<string | null>(null);
  const [importResult, setImportResult] = useState<ImportResult | null>(null);

  const [query, setQuery] = useState('');
  const [search, setSearch] = useState('');
  const [list, setList] = useState<SocietyList | null>(null);
  const [listError, setListError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [removingId, setRemovingId] = useState<string | null>(null);

  const loadQuota = useCallback(async () => {
    const result = await apiRequest<{ items: PlatformSetting[] }>('/platform-settings', { token });
    const row = result.items.find((item) => item.settingKey === 'society_free_quota_config');
    if (row) {
      const raw = row.settingValue as FreeQuotaForm & { freePages?: number };
      const freePages = combinedFreePages({ ...DEFAULT_QUOTA, ...raw });
      setQuota({
        period: raw.period || DEFAULT_QUOTA.period,
        freePages,
        freeBwPages: freePages,
        freeColorPages: freePages,
        combined: true,
      });
    }
  }, [token]);

  const loadList = useCallback(async () => {
    setLoading(true);
    setListError(null);
    try {
      const qs = search.trim() ? `?q=${encodeURIComponent(search.trim())}` : '';
      const result = await apiRequest<SocietyList>(`/society-phones${qs}`, { token });
      setList(result);
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Failed to load society phones');
      setList(null);
    } finally {
      setLoading(false);
    }
  }, [token, search]);

  useEffect(() => {
    if (!showQuota) return;
    void loadQuota().catch((err: unknown) => {
      setQuotaError(err instanceof Error ? err.message : 'Failed to load society quota');
    });
  }, [loadQuota, showQuota]);

  useEffect(() => {
    void loadList();
  }, [loadList]);

  async function saveQuota(event: FormEvent) {
    event.preventDefault();
    setSavingQuota(true);
    setQuotaError(null);
    setQuotaSaved(null);
    try {
      const freePages = combinedFreePages(quota);
      await apiRequest('/platform-settings/society_free_quota_config', {
        method: 'PUT',
        token,
        body: {
          settingValue: {
            period: quota.period,
            freePages,
            freeBwPages: freePages,
            freeColorPages: freePages,
            combined: true,
          },
        },
      });
      setQuota({
        period: quota.period,
        freePages,
        freeBwPages: freePages,
        freeColorPages: freePages,
        combined: true,
      });
      setQuotaSaved('Society free limit saved.');
    } catch (err) {
      setQuotaError(err instanceof Error ? err.message : 'Failed to save society quota');
    } finally {
      setSavingQuota(false);
    }
  }

  async function addPhone(event: FormEvent) {
    event.preventDefault();
    const phoneDigits = phone.replace(/\D/g, '');
    if (!/^[6-9]\d{9}$/.test(phoneDigits)) {
      setAddError('Enter a valid 10-digit Indian mobile number');
      return;
    }
    if (name.trim().length > 120) {
      setAddError('Person name must be 120 characters or fewer');
      return;
    }
    if (societyName.trim().length > 160) {
      setAddError('Society name must be 160 characters or fewer');
      return;
    }
    setAdding(true);
    setAddError(null);
    try {
      await apiRequest('/society-phones', {
        method: 'POST',
        token,
        body: {
          phone: phoneDigits,
          name: name.trim(),
          societyName: societyName.trim(),
        },
      });
      setPhone('');
      setName('');
      setSocietyName('');
      await loadList();
    } catch (err) {
      setAddError(err instanceof Error ? err.message : 'Failed to add number');
    } finally {
      setAdding(false);
    }
  }

  async function importFile(event: FormEvent) {
    event.preventDefault();
    if (!file) {
      setImportError('Choose a CSV or Excel file');
      return;
    }
    setImporting(true);
    setImportError(null);
    setImportResult(null);
    try {
      const form = new FormData();
      form.append('file', file);
      const result = await apiRequest<ImportResult>('/society-phones/import', {
        method: 'POST',
        token,
        formData: form,
      });
      setImportResult(result);
      setFile(null);
      setFileKey((key) => key + 1);
      await loadList();
    } catch (err) {
      setImportError(err instanceof Error ? err.message : 'Failed to import numbers');
    } finally {
      setImporting(false);
    }
  }

  async function removePhone(item: SocietyPhone) {
    const person = item.name?.trim() || item.phone;
    const society = item.societyName?.trim();
    const label = society ? `${person} · ${society} (${item.phone})` : `${person} (${item.phone})`;
    if (!window.confirm(`Remove ${label} from the society list?`)) return;
    setRemovingId(item.id);
    setListError(null);
    try {
      await apiRequest(`/society-phones/${item.id}`, { method: 'DELETE', token });
      await loadList();
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Failed to remove number');
    } finally {
      setRemovingId(null);
    }
  }

  return (
    <div className="space-y-6">
      {embedded ? null : (
        <PageHeader
          title="Society phones"
          subtitle="Listed numbers share one free-page pool for B/W and color. The kiosk session cap and night free-disabled window still apply."
        />
      )}

      {showQuota ? (
        <Panel title="Society free limit">
          <form onSubmit={(event) => void saveQuota(event)}>
            <div className="settings-row">
              <label>
                Period
                <Select
                  value={quota.period}
                  onChange={(e) => setQuota((s) => ({ ...s, period: e.target.value as QuotaPeriod }))}
                >
                  <option value="daily">Daily</option>
                  <option value="weekly">Weekly</option>
                  <option value="monthly">Monthly</option>
                </Select>
              </label>
              <label>
                Free pages (B/W + color combined)
                <Input
                  type="number"
                  min={0}
                  max={500}
                  value={quota.freePages}
                  onChange={(e) => {
                    const raw = e.target.value;
                    const next = raw === '' ? '' : Math.max(0, Math.min(500, Number(raw) || 0));
                    setQuota((s) => ({
                      ...s,
                      freePages: next,
                      freeBwPages: next,
                      freeColorPages: next,
                      combined: true,
                    }));
                  }}
                />
              </label>
            </div>
            <p className="mt-2 text-xs text-muted-foreground">
              One pool for black-and-white and color together (e.g. 10 total pages).
            </p>
            {quotaError ? <p className="error">{quotaError}</p> : null}
            {quotaSaved ? <p className="text-sm text-muted-foreground">{quotaSaved}</p> : null}
            <div className="mt-4">
              <Button type="submit" disabled={savingQuota}>
                {savingQuota ? 'Saving…' : 'Save limit'}
              </Button>
            </div>
          </form>
        </Panel>
      ) : null}

      {embedded ? (
        <div className="rounded-xl border border-emerald-500/25 bg-gradient-to-br from-emerald-500/10 via-card to-card px-4 py-3 text-sm">
          <p className="font-medium text-emerald-900 dark:text-emerald-100">
            {list
              ? `${list.total} number${list.total === 1 ? '' : 's'} on the society free list`
              : 'Society free list'}
          </p>
          <p className="mt-1 text-muted-foreground">
            Add a mobile (name and society optional) — or upload CSV / Excel. Removing a number
            does not erase past ledger history.
          </p>
        </div>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-2">
        <Panel title="Add one number">
          <form className="space-y-3" onSubmit={(event) => void addPhone(event)}>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Person name (optional)"
              maxLength={120}
            />
            <Input
              value={societyName}
              onChange={(e) => setSocietyName(e.target.value)}
              placeholder="Society name (optional)"
              maxLength={160}
            />
            <Input
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="10-digit mobile number"
              inputMode="numeric"
              maxLength={14}
              required
            />
            <Button
              type="submit"
              disabled={adding || phone.replace(/\D/g, '').length < 10}
            >
              {adding ? 'Adding…' : 'Add number'}
            </Button>
          </form>
          {addError ? <p className="error">{addError}</p> : null}
        </Panel>

        <Panel title="Upload CSV or Excel">
          <form className="space-y-3" onSubmit={(event) => void importFile(event)}>
            <p className="text-sm text-muted-foreground">
              Columns: phone (required), optional name and society / societyName. Upload adds only —
              it does not remove existing numbers. Save .xls as .xlsx.
            </p>
            <input
              key={fileKey}
              type="file"
              accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              onChange={(e) => {
                setFile(e.target.files?.[0] ?? null);
                setImportResult(null);
                setImportError(null);
              }}
            />
            <div>
              <Button type="submit" disabled={importing || !file}>
                {importing ? 'Uploading…' : 'Upload'}
              </Button>
            </div>
          </form>
          {importError ? <p className="error">{importError}</p> : null}
          {importResult ? (
            <div className="mt-3 text-sm">
              <p>
                Added {importResult.added}. Already listed or repeated in the file:{' '}
                {importResult.duplicate}. Invalid: {importResult.invalidCount}.
              </p>
              {importResult.invalid.length > 0 ? (
                <ul className="mt-2 list-disc pl-5 text-muted-foreground">
                  {importResult.invalid.map((row) => (
                    <li key={`${row.row}-${row.value}`}>
                      Row {row.row}: {row.value}
                    </li>
                  ))}
                </ul>
              ) : null}
            </div>
          ) : null}
        </Panel>
      </div>

      <Panel
        title="Society list"
        actions={
          list ? (
            <span className="text-xs text-muted-foreground">
              {list.items.length} shown
              {list.total > list.items.length ? ` of ${list.total}` : ''}
            </span>
          ) : null
        }
      >
        <form
          className="mb-4 flex flex-col gap-2 sm:flex-row sm:items-center"
          onSubmit={(e) => {
            e.preventDefault();
            setSearch(query.trim());
          }}
        >
          <Input
            placeholder="Search by person, society, or phone"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="sm:max-w-xs"
          />
          <Button type="submit" disabled={loading}>
            {loading ? 'Loading…' : 'Search'}
          </Button>
        </form>
        {listError ? <p className="error">{listError}</p> : null}
        {!loading && !listError && (list?.items.length ?? 0) === 0 ? (
          <EmptyState
            title="No society numbers yet"
            description="Add a 10-digit mobile (name and society optional) — or upload a CSV or Excel file."
          />
        ) : null}
        {list && list.items.length > 0 ? (
          <table className="table">
            <thead>
              <tr>
                <th>Person</th>
                <th>Society</th>
                <th>Phone</th>
                <th>Added</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {list.items.map((item) => (
                <tr key={item.id}>
                  <td className="font-medium">{item.name?.trim() || '—'}</td>
                  <td>{item.societyName?.trim() || '—'}</td>
                  <td className="font-mono text-sm font-medium">{item.phone}</td>
                  <td className="text-muted-foreground">
                    {new Date(item.createdAt).toLocaleString()}
                  </td>
                  <td>
                    <div className="flex flex-wrap items-center justify-end gap-2">
                      <Link
                        to={`/free-print?tab=usage&q=${encodeURIComponent(item.phone)}`}
                        className="text-sm font-medium text-primary hover:underline"
                      >
                        Track usage
                      </Link>
                      <Button
                        type="button"
                        variant="ghost"
                        disabled={removingId === item.id}
                        onClick={() => void removePhone(item)}
                      >
                        {removingId === item.id ? 'Removing…' : 'Remove'}
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : null}
        {list && list.total > list.items.length ? (
          <p className="mt-3 text-sm text-muted-foreground">
            Showing {list.items.length} of {list.total}. Search to narrow the list.
          </p>
        ) : null}
      </Panel>
    </div>
  );
}
