import { useEffect, useMemo, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  EmptyState,
  FilterChips,
  PaginationBar,
  Panel,
  Toolbar,
  paginateItems,
} from '../../core/ui/primitives';

type AuditLog = {
  id: string;
  action: string;
  principalType: string;
  resourceType: string | null;
  resourceId?: string | null;
  correlationId: string | null;
  metadata?: Record<string, unknown> | null;
  createdAt: string;
};

const ACTION_LABELS: Record<string, string> = {
  'ads.advertiser_created': 'Advertiser created',
  'ads.campaign_created': 'Campaign created',
  'ads.campaign_active': 'Campaign activated',
  'ads.campaign_paused': 'Campaign paused',
  'ads.campaign_ended': 'Campaign ended',
  'ads.creative_uploaded': 'Creative uploaded',
  'astrology.reading_created': 'Astrology reading created',
  'auth.admin_login': 'Admin signed in',
  'auth.citizen_login': 'Citizen signed in',
  'auth.citizen_otp_requested': 'Citizen OTP requested',
  'auth.device_token': 'Device token issued',
  'device.activated': 'Kiosk activated',
  'device.deactivated': 'Kiosk deactivated',
  'device.registered': 'Kiosk registered',
  'device.surveillance_started': 'Surveillance started',
  'device.surveillance_stopped': 'Surveillance stopped',
  'digilocker.print_requested': 'DigiLocker print requested',
  'digilocker.session_authorized': 'DigiLocker session authorized',
  'digilocker.session_cancelled': 'DigiLocker session cancelled',
  'digilocker.session_started': 'DigiLocker session started',
  'otp.created': 'Print OTP created',
  'otp.issued': 'Print OTP issued',
  'otp.redeemed': 'Print OTP redeemed',
  'otp.document_print_job': 'OTP document print job',
  'quick_print.session_started': 'Quick Print session started',
  'quick_print.uploaded': 'Quick Print documents uploaded',
  'quick_print.paid': 'Quick Print payment received',
  'quick_print.claimed': 'Quick Print claimed',
  'quick_print.cancelled': 'Quick Print cancelled',
  'payment.order_created': 'Payment order created',
  'payment.paid': 'Payment received',
  'platform_setting.updated': 'Platform setting updated',
  'print_job.created': 'Print job created',
  'print_job.ready': 'Print job ready',
  'print_job.printing': 'Print job printing',
  'print_job.completed': 'Print job completed',
  'print_job.failed': 'Print job failed',
  'print_job.expired': 'Print job expired',
  'print_job.admin_close': 'Print job cleared by admin',
  'service.enablement_updated': 'Service enablement updated',
  'surveillance.playback': 'Recording played',
  'surveillance.segment_uploaded': 'Recording uploaded',
  'surveillance.segment_dismiss': 'Recording dismissed',
  'surveillance.segments_dismiss_orphans': 'Errored pending recordings dismissed',
  'surveillance.upload_url': 'Recording upload URL issued',
  'surveillance.command_create': 'Surveillance command created',
  'diagnostics.bundle_upload_url': 'Diagnostics upload URL issued',
  'diagnostics.bundle_uploaded': 'Diagnostics bundle uploaded',
  'diagnostics.bundle_download': 'Diagnostics bundle downloaded',
};

const PRINCIPAL_LABELS: Record<string, string> = {
  admin: 'Admin',
  citizen: 'Citizen',
  device: 'Device',
  system: 'System',
};

const RESOURCE_LABELS: Record<string, string> = {
  advertiser: 'Advertiser',
  campaign: 'Campaign',
  creative: 'Creative',
  device: 'Kiosk',
  digilocker_session: 'DigiLocker session',
  otp_session: 'Print OTP',
  otp_document: 'OTP document',
  quick_print_session: 'Quick Print',
  payment: 'Payment',
  platform_setting: 'Platform setting',
  print_job: 'Print job',
  service: 'Service',
  surveillance_segment: 'Recording',
};

const CATEGORY_FILTERS = [
  { value: 'all', label: 'All' },
  { value: 'auth', label: 'Auth' },
  { value: 'print', label: 'Print' },
  { value: 'digilocker', label: 'DigiLocker' },
  { value: 'device', label: 'Device' },
  { value: 'surveillance', label: 'Recordings' },
  { value: 'diagnostics', label: 'Diagnostics' },
  { value: 'ads', label: 'Ads' },
  { value: 'other', label: 'Other' },
] as const;

const PRINCIPAL_FILTERS = [
  { value: 'all', label: 'All actors' },
  { value: 'admin', label: 'Admin' },
  { value: 'citizen', label: 'Citizen' },
  { value: 'device', label: 'Device' },
  { value: 'system', label: 'System' },
] as const;

type Category = (typeof CATEGORY_FILTERS)[number]['value'];
type PrincipalFilter = (typeof PRINCIPAL_FILTERS)[number]['value'];

function humanize(value: string): string {
  return value
    .replace(/[._]/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function actionLabel(action: string): string {
  return ACTION_LABELS[action] ?? humanize(action);
}

function principalLabel(principalType: string): string {
  return PRINCIPAL_LABELS[principalType] ?? humanize(principalType);
}

function resourceLabel(resourceType: string | null): string {
  if (!resourceType) {
    return '—';
  }
  return RESOURCE_LABELS[resourceType] ?? humanize(resourceType);
}

function categoryOf(action: string): Exclude<Category, 'all'> {
  if (action.startsWith('auth.')) return 'auth';
  if (
    action.startsWith('print_job.') ||
    action.startsWith('otp.') ||
    action.startsWith('quick_print.') ||
    action.startsWith('payment.')
  ) {
    return 'print';
  }
  if (action.startsWith('digilocker.')) return 'digilocker';
  if (action.startsWith('device.')) return 'device';
  if (action.startsWith('surveillance.')) return 'surveillance';
  if (action.startsWith('diagnostics.')) return 'diagnostics';
  if (action.startsWith('ads.')) return 'ads';
  return 'other';
}

function metaString(metadata: Record<string, unknown> | null | undefined, key: string): string | null {
  const value = metadata?.[key];
  if (typeof value === 'string' && value.trim()) return value.trim();
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  return null;
}

function detailLine(log: AuditLog): string | null {
  const meta = log.metadata ?? undefined;
  const parts = [
    metaString(meta, 'title'),
    metaString(meta, 'source'),
    metaString(meta, 'printColorMode'),
    metaString(meta, 'status'),
    metaString(meta, 'errorMessage'),
    metaString(meta, 'reason'),
  ].filter(Boolean);
  if (parts.length > 0) return parts.join(' · ');
  if (log.resourceId) return log.resourceId.slice(0, 8);
  return null;
}

export function AuditLogsPanel() {
  const { token } = useAuth();
  const [items, setItems] = useState<AuditLog[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [category, setCategory] = useState<Category>('all');
  const [principal, setPrincipal] = useState<PrincipalFilter>('all');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);

  useEffect(() => {
    void (async () => {
      try {
        const result = await apiRequest<{ items: AuditLog[] }>('/audit-logs?limit=200', {
          token,
        });
        setItems(result.items);
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load audit logs');
      }
    })();
  }, [token]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter((log) => {
      if (category !== 'all' && categoryOf(log.action) !== category) {
        return false;
      }
      if (principal !== 'all' && log.principalType !== principal) {
        return false;
      }
      if (!q) {
        return true;
      }
      const haystack = [
        log.action,
        actionLabel(log.action),
        log.principalType,
        principalLabel(log.principalType),
        log.resourceType ?? '',
        resourceLabel(log.resourceType),
        log.resourceId ?? '',
        detailLine(log) ?? '',
        JSON.stringify(log.metadata ?? {}),
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [items, category, principal, search]);

  useEffect(() => {
    setPage(1);
  }, [category, principal, search, pageSize]);

  const paged = useMemo(
    () => paginateItems(filtered, page, pageSize),
    [filtered, page, pageSize],
  );

  return (
    <div>
      {error ? <p className="error mb-4">{error}</p> : null}
      <Panel>
        <Toolbar search={search} onSearchChange={setSearch} searchPlaceholder="Search actions">
          <FilterChips
            options={[...CATEGORY_FILTERS]}
            value={category}
            onChange={(value) => setCategory(value as Category)}
          />
          <FilterChips
            options={[...PRINCIPAL_FILTERS]}
            value={principal}
            onChange={(value) => setPrincipal(value as PrincipalFilter)}
          />
        </Toolbar>

        {filtered.length === 0 ? (
          <EmptyState
            title={items.length === 0 ? 'No audit events yet' : 'No matches'}
            description={
              items.length === 0
                ? 'Logins, prints, DigiLocker sessions, and admin changes will appear here. Kiosk heartbeats stay on the Kiosks page.'
                : 'Adjust filters or search.'
            }
          />
        ) : (
          <>
            <table className="table">
              <thead>
                <tr>
                  <th>Action</th>
                  <th>Who</th>
                  <th>Resource</th>
                  <th>When</th>
                </tr>
              </thead>
              <tbody>
                {paged.items.map((log) => {
                  const detail = detailLine(log);
                  return (
                    <tr key={log.id} title={log.correlationId ?? undefined}>
                      <td>
                        <div>{actionLabel(log.action)}</div>
                        <div className="muted">{log.action}</div>
                        {detail ? (
                          <div className="mt-1 text-xs text-muted-foreground">{detail}</div>
                        ) : null}
                      </td>
                      <td>{principalLabel(log.principalType)}</td>
                      <td>
                        <div>{resourceLabel(log.resourceType)}</div>
                        {log.resourceId ? (
                          <div className="font-mono text-xs text-muted-foreground">
                            {log.resourceId.slice(0, 8)}
                          </div>
                        ) : null}
                      </td>
                      <td>{new Date(log.createdAt).toLocaleString()}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            <PaginationBar
              page={paged.page}
              pageSize={pageSize}
              total={filtered.length}
              onPageChange={setPage}
              onPageSizeChange={setPageSize}
            />
          </>
        )}
      </Panel>
    </div>
  );
}
