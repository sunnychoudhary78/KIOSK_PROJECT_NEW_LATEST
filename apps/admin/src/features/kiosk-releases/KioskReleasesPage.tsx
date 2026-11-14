import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import { apiRequest, putFileToPresignedUrl } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  EmptyState,
  FilterChips,
  Input,
  PageHeader,
  Panel,
  Toolbar,
} from '../../core/ui/primitives';

type ReleaseStatus = 'pending_upload' | 'uploaded' | 'active';

type KioskAppRelease = {
  id: string;
  version: string;
  objectKey: string;
  contentType: string;
  byteSize: number;
  sha256: string;
  status: ReleaseStatus;
  createdByAdminId: string | null;
  uploadedAt: string | null;
  activatedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

type ReleaseList = {
  items: KioskAppRelease[];
};

type CreateReleaseResponse = {
  release: KioskAppRelease;
  uploadUrl: string;
  expiresAt: string;
};

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

function statusLabel(status: ReleaseStatus): string {
  if (status === 'active') return 'Active';
  if (status === 'uploaded') return 'Uploaded';
  return 'Pending upload';
}

async function sha256Hex(file: File): Promise<string> {
  const buffer = await file.arrayBuffer();
  const digest = await crypto.subtle.digest('SHA-256', buffer);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export function KioskReleasesPage() {
  const { token } = useAuth();
  const [list, setList] = useState<ReleaseList | null>(null);
  const [loading, setLoading] = useState(false);
  const [listError, setListError] = useState<string | null>(null);

  const [version, setVersion] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [progressPercent, setProgressPercent] = useState<number | null>(null);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | ReleaseStatus>('all');

  const loadList = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setListError(null);
    try {
      const result = await apiRequest<ReleaseList>('/kiosk-releases', { token });
      setList(result);
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Failed to load releases');
      setList(null);
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    void loadList();
  }, [loadList]);

  const active = useMemo(
    () => list?.items.find((item) => item.status === 'active') ?? null,
    [list],
  );

  const filtered = useMemo(() => {
    const items = list?.items ?? [];
    const q = search.trim().toLowerCase();
    return items.filter((item) => {
      if (statusFilter !== 'all' && item.status !== statusFilter) return false;
      if (!q) return true;
      return [item.version, item.status, item.sha256].join(' ').toLowerCase().includes(q);
    });
  }, [list, search, statusFilter]);

  async function onUpload(event: FormEvent) {
    event.preventDefault();
    if (!token || !file) {
      setUploadError('Choose a zip build to upload');
      return;
    }
    const trimmed = version.trim();
    if (!trimmed) {
      setUploadError('Enter a version number');
      return;
    }
    if (!file.name.toLowerCase().endsWith('.zip')) {
      setUploadError('Upload a .zip of the Flutter Windows build');
      return;
    }

    setUploading(true);
    setUploadError(null);
    setNotice(null);
    setProgressPercent(0);

    try {
      const sha256 = await sha256Hex(file);
      const contentType =
        file.type === 'application/x-zip-compressed'
          ? 'application/x-zip-compressed'
          : 'application/zip';

      const created = await apiRequest<CreateReleaseResponse>('/kiosk-releases', {
        method: 'POST',
        token,
        body: {
          version: trimmed,
          contentType,
          byteSize: file.size,
          sha256,
        },
      });

      await putFileToPresignedUrl({
        url: created.uploadUrl,
        file,
        contentType,
        onProgress: (progress) => setProgressPercent(progress.percent),
      });

      await apiRequest(`/kiosk-releases/${created.release.id}/complete`, {
        method: 'POST',
        token,
      });

      setVersion('');
      setFile(null);
      setProgressPercent(100);
      setNotice(`Uploaded ${trimmed}. Activate it when ready for the fleet.`);
      await loadList();
    } catch (err) {
      setUploadError(err instanceof Error ? err.message : 'Upload failed');
    } finally {
      setUploading(false);
    }
  }

  async function activate(id: string) {
    if (!token) return;
    setBusyId(id);
    setNotice(null);
    setListError(null);
    try {
      await apiRequest(`/kiosk-releases/${id}/activate`, { method: 'POST', token });
      setNotice('Active version updated. Updaters will pick this up on the next poll.');
      await loadList();
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Could not activate release');
    } finally {
      setBusyId(null);
    }
  }

  async function remove(id: string) {
    if (!token) return;
    if (!window.confirm('Delete this release and its build from storage?')) return;
    setBusyId(id);
    setNotice(null);
    setListError(null);
    try {
      await apiRequest(`/kiosk-releases/${id}`, { method: 'DELETE', token });
      setNotice('Release deleted.');
      await loadList();
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Could not delete release');
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div>
      <PageHeader
        title="Kiosk updates"
        subtitle="Upload a Flutter Windows build zip and activate the global live version for fleet updaters."
      />
      {listError ? <p className="mb-4 text-sm text-red-600">{listError}</p> : null}
      {uploadError ? <p className="mb-4 text-sm text-red-600">{uploadError}</p> : null}
      {notice ? <p className="mb-4 text-sm text-emerald-700">{notice}</p> : null}

      <div className="mb-6">
        <Panel title="Live version">
          {active ? (
            <p className="text-sm">
              <span className="font-medium">{active.version}</span>
              <span className="text-muted-foreground">
                {' '}
                · {formatBytes(active.byteSize)}
                {active.activatedAt
                  ? ` · activated ${new Date(active.activatedAt).toLocaleString()}`
                  : ''}
              </span>
            </p>
          ) : (
            <p className="text-sm text-muted-foreground">No active release yet.</p>
          )}
        </Panel>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Panel title="Upload build">
          <form className="space-y-4" onSubmit={onUpload}>
            <label className="block text-sm">
              <span className="mb-1 block text-muted-foreground">Version</span>
              <Input
                required
                placeholder="1.2.0"
                value={version}
                disabled={uploading}
                onChange={(event) => setVersion(event.target.value)}
              />
            </label>
            <label className="block text-sm">
              <span className="mb-1 block text-muted-foreground">Windows build (.zip)</span>
              <Input
                type="file"
                accept=".zip,application/zip,application/x-zip-compressed"
                disabled={uploading}
                onChange={(event) => setFile(event.target.files?.[0] ?? null)}
              />
            </label>
            {uploading || progressPercent !== null ? (
              <p className="text-sm text-muted-foreground">
                {uploading
                  ? `Uploading${progressPercent != null ? ` ${progressPercent}%` : '…'}`
                  : progressPercent === 100
                    ? 'Upload complete'
                    : null}
              </p>
            ) : null}
            <Button type="submit" disabled={uploading || !file}>
              {uploading ? 'Uploading…' : 'Upload'}
            </Button>
          </form>
        </Panel>

        <Panel title="Releases">
          {loading && !list ? <p className="text-sm text-muted-foreground">Loading…</p> : null}
          {!loading && list && list.items.length === 0 ? (
            <EmptyState title="No releases" description="Upload the first Windows build zip." />
          ) : null}
          {list && list.items.length > 0 ? (
            <>
              <Toolbar
                search={search}
                onSearchChange={setSearch}
                searchPlaceholder="Search version"
              >
                <FilterChips
                  options={[
                    { value: 'all', label: 'All' },
                    { value: 'active', label: 'Active' },
                    { value: 'uploaded', label: 'Uploaded' },
                    { value: 'pending_upload', label: 'Pending' },
                  ]}
                  value={statusFilter}
                  onChange={(value) => setStatusFilter(value as typeof statusFilter)}
                />
              </Toolbar>
              {filtered.length === 0 ? (
                <EmptyState title="No matches" description="Adjust status filter or search." />
              ) : (
                <ul className="divide-y">
                  {filtered.map((item) => (
                    <li key={item.id} className="flex flex-wrap items-center gap-3 py-3 text-sm">
                      <div className="min-w-0 flex-1">
                        <p className="font-medium">{item.version}</p>
                        <p className="text-muted-foreground">
                          {statusLabel(item.status)} · {formatBytes(item.byteSize)} ·{' '}
                          {new Date(item.createdAt).toLocaleString()}
                        </p>
                      </div>
                      <div className="flex flex-wrap gap-2">
                        {item.status === 'uploaded' ? (
                          <Button
                            type="button"
                            disabled={busyId === item.id}
                            onClick={() => void activate(item.id)}
                          >
                            Activate
                          </Button>
                        ) : null}
                        {item.status !== 'active' ? (
                          <Button
                            type="button"
                            variant="secondary"
                            disabled={busyId === item.id}
                            onClick={() => void remove(item.id)}
                          >
                            Delete
                          </Button>
                        ) : null}
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </>
          ) : null}
        </Panel>
      </div>
    </div>
  );
}
