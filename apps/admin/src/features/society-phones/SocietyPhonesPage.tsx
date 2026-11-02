import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, EmptyState, Input, PageHeader, Panel, Select } from '../../core/ui/primitives';

type QuotaPeriod = 'daily' | 'weekly' | 'monthly';

type FreeQuotaForm = {
  period: QuotaPeriod;
  freeBwPages: number;
  freeColorPages: number;
};

type SocietyPhone = {
  id: string;
  phone: string;
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
  freeBwPages: 5,
  freeColorPages: 0,
};

export function SocietyPhonesPage() {
  const { token } = useAuth();
  const [quota, setQuota] = useState<FreeQuotaForm>(DEFAULT_QUOTA);
  const [quotaError, setQuotaError] = useState<string | null>(null);
  const [quotaSaved, setQuotaSaved] = useState<string | null>(null);
  const [savingQuota, setSavingQuota] = useState(false);

  const [phone, setPhone] = useState('');
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
      setQuota({ ...DEFAULT_QUOTA, ...row.settingValue });
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
    void loadQuota().catch((err: unknown) => {
      setQuotaError(err instanceof Error ? err.message : 'Failed to load society quota');
    });
  }, [loadQuota]);

  useEffect(() => {
    void loadList();
  }, [loadList]);

  async function saveQuota(event: FormEvent) {
    event.preventDefault();
    setSavingQuota(true);
    setQuotaError(null);
    setQuotaSaved(null);
    try {
      await apiRequest('/platform-settings/society_free_quota_config', {
        method: 'PUT',
        token,
        body: {
          settingValue: {
            period: quota.period,
            freeBwPages: Number(quota.freeBwPages),
            freeColorPages: Number(quota.freeColorPages),
          },
        },
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
    setAdding(true);
    setAddError(null);
    try {
      await apiRequest('/society-phones', {
        method: 'POST',
        token,
        body: { phone: phone.trim() },
      });
      setPhone('');
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
    if (!window.confirm(`Remove ${item.phone} from the society list?`)) return;
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
      <PageHeader
        title="Society phones"
        subtitle="Listed numbers use this free limit. The kiosk session cap and night free-disabled window still apply."
      />

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
              Free B/W pages
              <Input
                type="number"
                min={0}
                max={500}
                value={quota.freeBwPages}
                onChange={(e) => setQuota((s) => ({ ...s, freeBwPages: Number(e.target.value) }))}
              />
            </label>
            <label>
              Free color pages
              <Input
                type="number"
                min={0}
                max={500}
                value={quota.freeColorPages}
                onChange={(e) => setQuota((s) => ({ ...s, freeColorPages: Number(e.target.value) }))}
              />
            </label>
          </div>
          {quotaError ? <p className="error">{quotaError}</p> : null}
          {quotaSaved ? <p className="text-sm text-muted-foreground">{quotaSaved}</p> : null}
          <div className="mt-4">
            <Button type="submit" disabled={savingQuota}>
              {savingQuota ? 'Saving…' : 'Save limit'}
            </Button>
          </div>
        </form>
      </Panel>

      <Panel title="Add one number">
        <form className="flex flex-col gap-2 sm:flex-row sm:items-center" onSubmit={(event) => void addPhone(event)}>
          <Input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="10-digit mobile number"
            className="sm:max-w-xs"
          />
          <Button type="submit" disabled={adding || phone.trim().length === 0}>
            {adding ? 'Adding…' : 'Add number'}
          </Button>
        </form>
        {addError ? <p className="error">{addError}</p> : null}
      </Panel>

      <Panel title="Upload CSV or Excel">
        <form className="space-y-3" onSubmit={(event) => void importFile(event)}>
          <p className="text-sm text-muted-foreground">
            Use a column named phone, mobile, or number. Without a header, the first column is used.
            Upload adds numbers and does not remove ones already on the list. .xls files need to be saved as .xlsx.
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
              Added {importResult.added}. Already listed or repeated in the file: {importResult.duplicate}.
              Invalid: {importResult.invalidCount}.
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

      <Panel title="Society list">
        <form
          className="mb-4 flex flex-col gap-2 sm:flex-row sm:items-center"
          onSubmit={(e) => {
            e.preventDefault();
            setSearch(query.trim());
          }}
        >
          <Input
            placeholder="Search by phone digits"
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
            description="Add a mobile number or upload a CSV or Excel file."
          />
        ) : null}
        {list && list.items.length > 0 ? (
          <table className="table">
            <thead>
              <tr>
                <th>Phone</th>
                <th>Added</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {list.items.map((item) => (
                <tr key={item.id}>
                  <td className="font-medium font-mono text-sm">{item.phone}</td>
                  <td className="text-muted-foreground">{new Date(item.createdAt).toLocaleString()}</td>
                  <td>
                    <Button
                      type="button"
                      variant="ghost"
                      disabled={removingId === item.id}
                      onClick={() => void removePhone(item)}
                    >
                      {removingId === item.id ? 'Removing…' : 'Remove'}
                    </Button>
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
