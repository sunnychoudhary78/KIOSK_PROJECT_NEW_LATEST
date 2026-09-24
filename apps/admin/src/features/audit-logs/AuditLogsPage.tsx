import { useEffect, useMemo, useState } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { EmptyState, FilterChips, PageHeader, Panel, Toolbar } from '../../core/ui/primitives';

type AuditLog = {
  id: string;
  action: string;
  principalType: string;
  resourceType: string | null;
  correlationId: string | null;
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
  'payment.order_created': 'Payment order created',
  'payment.paid': 'Payment received',
  'platform_setting.updated': 'Platform setting updated',
  'print_job.created': 'Print job created',
  'print_job.ready': 'Print job ready',
  'print_job.printing': 'Print job printing',
  'print_job.completed': 'Print job completed',
  'print_job.failed': 'Print job failed',
  'print_job.expired': 'Print job expired',
  'service.enablement_updated': 'Service enablement updated',
  'surveillance.playback': 'Recording played',
  'surveillance.segment_uploaded': 'Recording uploaded',
  'surveillance.upload_url': 'Recording upload URL issued',
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
  { value: 'ads', label: 'Ads' },
  { value: 'other', label: 'Other' },
] as const;

type Category = (typeof CATEGORY_FILTERS)[number]['value'];

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
  if (action.startsWith('print_job.') || action.startsWith('otp.')) return 'print';
  if (action.startsWith('digilocker.')) return 'digilocker';
  if (action.startsWith('device.')) return 'device';
  if (action.startsWith('ads.')) return 'ads';
  return 'other';
}

export function AuditLogsPage() {
  const { token } = useAuth();
  const [items, setItems] = useState<AuditLog[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [category, setCategory] = useState<Category>('all');
  const [search, setSearch] = useState('');

  useEffect(() => {
    void (async () => {
      try {
        const result = await apiRequest<{ items: AuditLog[] }>('/audit-logs', { token });
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
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [items, category, search]);

  return (
    <div>
      <PageHeader title="Audit logs" subtitle="Security and operations trail" />
      {error ? <p className="error mb-4">{error}</p> : null}
      <Panel>
        <Toolbar search={search} onSearchChange={setSearch} searchPlaceholder="Search actions">
          <FilterChips
            options={[...CATEGORY_FILTERS]}
            value={category}
            onChange={(value) => setCategory(value as Category)}
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
              {filtered.map((log) => (
                <tr key={log.id} title={log.correlationId ?? undefined}>
                  <td>
                    <div>{actionLabel(log.action)}</div>
                    <div className="muted">{log.action}</div>
                  </td>
                  <td>{principalLabel(log.principalType)}</td>
                  <td>{resourceLabel(log.resourceType)}</td>
                  <td>{new Date(log.createdAt).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
    </div>
  );
}
