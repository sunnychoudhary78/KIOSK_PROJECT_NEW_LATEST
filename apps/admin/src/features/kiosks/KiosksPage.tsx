import { useEffect, useState, type FormEvent } from 'react';
import {
  CloudUpload,
  PauseCircle,
  Settings,
  Video,
  VideoOff,
  AlertTriangle,
} from 'lucide-react';
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
} from '../../core/ui/primitives';
import {
  resolveRecordingDisplay,
  type SurveillanceHealth,
} from '../surveillance/surveillanceStatus';

type Device = {
  id: string;
  name: string;
  deviceKey: string;
  status: string;
  siteName: string;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  lastHeartbeatAt: string | null;
  surveillanceEnabled: boolean;
  surveillanceHealth?: SurveillanceHealth | null;
  surveillanceHealthAt?: string | null;
  maxPagesPerSession: number;
  freePagesPerSession: number;
  extraPageChargeRupees: number;
  freeColorPagesPerSession: number;
  extraColorPageChargeRupees: number;
  freeDisabledFromLocal?: string | null;
  freeDisabledToLocal?: string | null;
  bannerHorizontalEnabled?: boolean;
  bannerVerticalEnabled?: boolean;
};

function RecordingStatusCell({ device }: { device: Device }) {
  const display = resolveRecordingDisplay(device);
  const Icon =
    display.key === 'off'
      ? VideoOff
      : display.key === 'uploading'
        ? CloudUpload
        : display.key === 'paused_palm'
          ? PauseCircle
          : display.key === 'camera_error' || display.key === 'storage_low'
            ? AlertTriangle
            : Video;

  return (
    <span
      className={`inline-flex items-center gap-1.5 text-sm font-medium ${display.className}`}
      title={display.title}
    >
      <Icon className="h-4 w-4" />
      {display.label}
    </span>
  );
}

type PrintLimitsForm = {
  maxPagesPerSession: number;
  freePagesPerSession: number;
  extraPageChargeRupees: number;
  freeColorPagesPerSession: number;
  extraColorPageChargeRupees: number;
  freeDisabledFromLocal: string;
  freeDisabledToLocal: string;
  bannerHorizontalEnabled: boolean;
  bannerVerticalEnabled: boolean;
};

const DEFAULT_PRINT_LIMITS: PrintLimitsForm = {
  maxPagesPerSession: 10,
  freePagesPerSession: 5,
  extraPageChargeRupees: 10,
  freeColorPagesPerSession: 0,
  extraColorPageChargeRupees: 20,
  freeDisabledFromLocal: '',
  freeDisabledToLocal: '',
  bannerHorizontalEnabled: true,
  bannerVerticalEnabled: true,
};

function printLimitsFromDevice(device: Device): PrintLimitsForm {
  return {
    maxPagesPerSession: device.maxPagesPerSession ?? DEFAULT_PRINT_LIMITS.maxPagesPerSession,
    freePagesPerSession: device.freePagesPerSession ?? DEFAULT_PRINT_LIMITS.freePagesPerSession,
    extraPageChargeRupees: device.extraPageChargeRupees ?? DEFAULT_PRINT_LIMITS.extraPageChargeRupees,
    freeColorPagesPerSession:
      device.freeColorPagesPerSession ?? DEFAULT_PRINT_LIMITS.freeColorPagesPerSession,
    extraColorPageChargeRupees:
      device.extraColorPageChargeRupees ?? DEFAULT_PRINT_LIMITS.extraColorPageChargeRupees,
    freeDisabledFromLocal: device.freeDisabledFromLocal ?? '',
    freeDisabledToLocal: device.freeDisabledToLocal ?? '',
    bannerHorizontalEnabled: device.bannerHorizontalEnabled !== false,
    bannerVerticalEnabled: device.bannerVerticalEnabled !== false,
  };
}

type CreatedCredentials = {
  name: string;
  deviceKey: string;
  deviceSecret: string;
};

function formatLocation(device: Device): string {
  if (device.address?.trim()) return device.address.trim();
  if (device.latitude != null && device.longitude != null) {
    return `${device.latitude.toFixed(5)}, ${device.longitude.toFixed(5)}`;
  }
  return '—';
}

export function KiosksPage() {
  const { token } = useAuth();
  const [items, setItems] = useState<Device[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [name, setName] = useState('');
  const [siteName, setSiteName] = useState('');
  const [latitude, setLatitude] = useState('');
  const [longitude, setLongitude] = useState('');
  const [address, setAddress] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [credentials, setCredentials] = useState<CreatedCredentials | null>(null);
  const [copiedField, setCopiedField] = useState<'key' | 'secret' | null>(null);
  const [settingsDevice, setSettingsDevice] = useState<Device | null>(null);
  const [printLimits, setPrintLimits] = useState<PrintLimitsForm>(DEFAULT_PRINT_LIMITS);
  const [settingsError, setSettingsError] = useState<string | null>(null);
  const [settingsSaving, setSettingsSaving] = useState(false);

  async function load() {
    try {
      const result = await apiRequest<{ items: Device[] }>('/devices', { token });
      setItems(result.items);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load devices');
    }
  }

  useEffect(() => {
    void load();
  }, [token]);

  function resetForm() {
    setName('');
    setSiteName('');
    setLatitude('');
    setLongitude('');
    setAddress('');
    setFormError(null);
  }

  function openAdd() {
    resetForm();
    setAddOpen(true);
  }

  async function onRegister(event: FormEvent) {
    event.preventDefault();
    const trimmedName = name.trim();
    const trimmedSite = siteName.trim();
    const lat = Number(latitude);
    const lng = Number(longitude);
    if (!trimmedName || !trimmedSite) {
      setFormError('Device name and site name are required');
      return;
    }
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      setFormError('Latitude and longitude are required numbers');
      return;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      setFormError('Latitude must be −90…90 and longitude −180…180');
      return;
    }

    setSubmitting(true);
    setFormError(null);
    try {
      const result = await apiRequest<Device & { deviceSecret: string }>('/devices', {
        method: 'POST',
        token,
        body: {
          name: trimmedName,
          siteName: trimmedSite,
          latitude: lat,
          longitude: lng,
          address: address.trim() || undefined,
        },
      });
      setCredentials({
        name: result.name,
        deviceKey: result.deviceKey,
        deviceSecret: result.deviceSecret,
      });
      setCopiedField(null);
      setAddOpen(false);
      resetForm();
      await load();
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to register device');
    } finally {
      setSubmitting(false);
    }
  }

  async function onSetStatus(device: Device, status: 'active' | 'inactive') {
    if (status === 'inactive') {
      const ok = window.confirm(
        `Stop “${device.name}”? This kiosk will go offline until you Start it again.`,
      );
      if (!ok) {
        return;
      }
    }
    setSubmitting(true);
    setError(null);
    try {
      await apiRequest(`/devices/${device.id}/status`, {
        method: 'PATCH',
        token,
        body: { status },
      });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update kiosk');
    } finally {
      setSubmitting(false);
    }
  }

  async function onSetSurveillance(device: Device, enabled: boolean) {
    if (enabled) {
      const ok = window.confirm(
        `Start 24/7 camera recording on “${device.name}”? Visitors at this kiosk must be notified that video surveillance is in use.`,
      );
      if (!ok) {
        return;
      }
    }
    setSubmitting(true);
    setError(null);
    try {
      await apiRequest(`/devices/${device.id}/surveillance`, {
        method: 'PATCH',
        token,
        body: { enabled },
      });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update surveillance');
    } finally {
      setSubmitting(false);
    }
  }

  function openSettings(device: Device) {
    setSettingsDevice(device);
    setPrintLimits(printLimitsFromDevice(device));
    setSettingsError(null);
  }

  async function onSavePrintLimits(event: FormEvent) {
    event.preventDefault();
    if (!settingsDevice) {
      return;
    }
    if (printLimits.freePagesPerSession > printLimits.maxPagesPerSession) {
      setSettingsError('Black & white free pages cannot exceed max pages');
      return;
    }
    if (printLimits.freeColorPagesPerSession > printLimits.maxPagesPerSession) {
      setSettingsError('Color free pages cannot exceed max pages');
      return;
    }
    setSettingsSaving(true);
    setSettingsError(null);
    try {
      const from = printLimits.freeDisabledFromLocal.trim();
      const to = printLimits.freeDisabledToLocal.trim();
      if ((from && !to) || (!from && to)) {
        setSettingsError('Set both free-disabled from and to times, or clear both');
        setSettingsSaving(false);
        return;
      }
      await apiRequest(`/devices/${settingsDevice.id}/print-limits`, {
        method: 'PATCH',
        token,
        body: {
          maxPagesPerSession: Number(printLimits.maxPagesPerSession),
          freePagesPerSession: Number(printLimits.freePagesPerSession),
          extraPageChargeRupees: Number(printLimits.extraPageChargeRupees),
          freeColorPagesPerSession: Number(printLimits.freeColorPagesPerSession),
          extraColorPageChargeRupees: Number(printLimits.extraColorPageChargeRupees),
          freeDisabledFromLocal: from || null,
          freeDisabledToLocal: to || null,
          bannerHorizontalEnabled: printLimits.bannerHorizontalEnabled,
          bannerVerticalEnabled: printLimits.bannerVerticalEnabled,
        },
      });
      setSettingsDevice(null);
      await load();
    } catch (err) {
      setSettingsError(err instanceof Error ? err.message : 'Failed to save print limits');
    } finally {
      setSettingsSaving(false);
    }
  }

  async function copyValue(field: 'key' | 'secret', value: string) {
    try {
      await navigator.clipboard.writeText(value);
      setCopiedField(field);
    } catch {
      setError('Could not copy to clipboard');
    }
  }

  return (
    <div>
      <PageHeader
        title="Kiosks"
        subtitle="Register a Windows terminal, then paste the credentials into the kiosk Activate screen"
        actions={
          <Button type="button" onClick={openAdd}>
            Add kiosk
          </Button>
        }
      />

      {error ? <p className="error mb-4">{error}</p> : null}

      {credentials ? (
        <Panel title={`Device credentials for ${credentials.name}`}>
          <div className="credentials-panel">
            <p className="warning">
              The device secret is shown only once. Copy both values now and paste them into the
              Windows kiosk Activate screen.
            </p>

            <div className="credential-row">
              <label>
                Device key
                <Input readOnly value={credentials.deviceKey} />
              </label>
              <Button type="button" onClick={() => void copyValue('key', credentials.deviceKey)}>
                {copiedField === 'key' ? 'Copied' : 'Copy key'}
              </Button>
            </div>

            <div className="credential-row">
              <label>
                Device secret
                <Input readOnly value={credentials.deviceSecret} />
              </label>
              <Button
                type="button"
                onClick={() => void copyValue('secret', credentials.deviceSecret)}
              >
                {copiedField === 'secret' ? 'Copied' : 'Copy secret'}
              </Button>
            </div>

            <Button type="button" variant="secondary" onClick={() => setCredentials(null)}>
              Dismiss
            </Button>
          </div>
        </Panel>
      ) : null}

      <Panel title="Registered kiosks">
        {items.length === 0 ? (
          <EmptyState
            title="No devices registered yet"
            description="Add a kiosk, then paste the credentials into the Windows Activate screen."
            action={
              <Button type="button" onClick={openAdd}>
                Add kiosk
              </Button>
            }
          />
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Site</th>
                <th>Location</th>
                <th>Status</th>
                <th>Device key</th>
                <th>Last heartbeat</th>
                <th>Recording</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {items.map((device) => (
                <tr key={device.id}>
                  <td className="font-medium">{device.name}</td>
                  <td>{device.siteName}</td>
                  <td>{formatLocation(device)}</td>
                  <td>
                    <StatusBadge status={device.status} />
                  </td>
                  <td>
                    <code>{device.deviceKey}</code>
                  </td>
                  <td className="text-muted-foreground">
                    {device.lastHeartbeatAt
                      ? new Date(device.lastHeartbeatAt).toLocaleString()
                      : '—'}
                  </td>
                  <td>
                    <RecordingStatusCell device={device} />
                  </td>
                  <td>
                    <div className="row-actions">
                      {device.status === 'inactive' ? (
                        <Button
                          type="button"
                          variant="secondary"
                          disabled={submitting}
                          onClick={() => void onSetStatus(device, 'active')}
                        >
                          Start
                        </Button>
                      ) : (
                        <Button
                          type="button"
                          variant="danger"
                          disabled={submitting}
                          onClick={() => void onSetStatus(device, 'inactive')}
                        >
                          Stop
                        </Button>
                      )}
                      <Button
                        type="button"
                        variant="secondary"
                        disabled={submitting}
                        onClick={() => openSettings(device)}
                      >
                        <span className="inline-flex items-center gap-1.5">
                          <Settings className="h-4 w-4" />
                          Settings
                        </span>
                      </Button>
                      {device.surveillanceEnabled ? (
                        <Button
                          type="button"
                          variant="secondary"
                          disabled={submitting || device.status === 'inactive'}
                          onClick={() => void onSetSurveillance(device, false)}
                        >
                          Stop surveillance
                        </Button>
                      ) : (
                        <Button
                          type="button"
                          variant="secondary"
                          disabled={submitting || device.status === 'inactive'}
                          onClick={() => void onSetSurveillance(device, true)}
                        >
                          Start surveillance
                        </Button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>

      <Modal
        open={addOpen}
        title="Add kiosk"
        onClose={() => {
          if (!submitting) {
            setAddOpen(false);
          }
        }}
        footer={
          <>
            <Button
              type="button"
              variant="ghost"
              disabled={submitting}
              onClick={() => setAddOpen(false)}
            >
              Cancel
            </Button>
            <Button type="submit" form="register-kiosk-form" disabled={submitting}>
              {submitting ? 'Registering…' : 'Register device'}
            </Button>
          </>
        }
      >
        <form id="register-kiosk-form" className="grid gap-4 md:grid-cols-2" onSubmit={(e) => void onRegister(e)}>
          <label>
            Device name
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Lobby Kiosk"
              required
            />
          </label>
          <label>
            Site name
            <Input
              value={siteName}
              onChange={(e) => setSiteName(e.target.value)}
              placeholder="Demo Site"
              required
            />
          </label>
          <label>
            Latitude
            <Input
              value={latitude}
              onChange={(e) => setLatitude(e.target.value)}
              placeholder="28.613900"
              inputMode="decimal"
              required
            />
          </label>
          <label>
            Longitude
            <Input
              value={longitude}
              onChange={(e) => setLongitude(e.target.value)}
              placeholder="77.209000"
              inputMode="decimal"
              required
            />
          </label>
          <label className="md:col-span-2">
            Address (optional)
            <Input
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              placeholder="City Mall, Gate 2"
            />
          </label>
          {formError ? <p className="error md:col-span-2">{formError}</p> : null}
        </form>
      </Modal>

      <Modal
        open={settingsDevice != null}
        title={settingsDevice ? `Print limits · ${settingsDevice.name}` : 'Print limits'}
        onClose={() => {
          if (!settingsSaving) {
            setSettingsDevice(null);
          }
        }}
        footer={
          <>
            <Button
              type="button"
              variant="ghost"
              disabled={settingsSaving}
              onClick={() => setSettingsDevice(null)}
            >
              Cancel
            </Button>
            <Button type="submit" form="kiosk-print-limits-form" disabled={settingsSaving}>
              {settingsSaving ? 'Saving…' : 'Save limits'}
            </Button>
          </>
        }
      >
        <form
          id="kiosk-print-limits-form"
          className="grid gap-4 md:grid-cols-2"
          onSubmit={(e) => void onSavePrintLimits(e)}
        >
          <label>
            Max pages / session
            <Input
              type="number"
              min={1}
              max={100}
              value={printLimits.maxPagesPerSession}
              onChange={(e) =>
                setPrintLimits((s) => ({ ...s, maxPagesPerSession: Number(e.target.value) }))
              }
            />
          </label>
          <label>
            Black & white free pages
            <Input
              type="number"
              min={0}
              max={100}
              value={printLimits.freePagesPerSession}
              onChange={(e) =>
                setPrintLimits((s) => ({ ...s, freePagesPerSession: Number(e.target.value) }))
              }
            />
          </label>
          <label>
            Black & white extra page charge (₹)
            <Input
              type="number"
              min={0}
              max={1000}
              value={printLimits.extraPageChargeRupees}
              onChange={(e) =>
                setPrintLimits((s) => ({ ...s, extraPageChargeRupees: Number(e.target.value) }))
              }
            />
          </label>
          <label>
            Color free pages
            <Input
              type="number"
              min={0}
              max={100}
              value={printLimits.freeColorPagesPerSession}
              onChange={(e) =>
                setPrintLimits((s) => ({
                  ...s,
                  freeColorPagesPerSession: Number(e.target.value),
                }))
              }
            />
          </label>
          <label>
            Color extra page charge (₹)
            <Input
              type="number"
              min={0}
              max={1000}
              value={printLimits.extraColorPageChargeRupees}
              onChange={(e) =>
                setPrintLimits((s) => ({
                  ...s,
                  extraColorPageChargeRupees: Number(e.target.value),
                }))
              }
            />
          </label>
          <label>
            Free disabled from (Asia/Kolkata)
            <Input
              type="time"
              value={printLimits.freeDisabledFromLocal}
              onChange={(e) =>
                setPrintLimits((s) => ({ ...s, freeDisabledFromLocal: e.target.value }))
              }
            />
          </label>
          <label>
            Free disabled to (Asia/Kolkata)
            <Input
              type="time"
              value={printLimits.freeDisabledToLocal}
              onChange={(e) =>
                setPrintLimits((s) => ({ ...s, freeDisabledToLocal: e.target.value }))
              }
            />
          </label>
          <p className="muted md:col-span-2" style={{ margin: 0 }}>
            Session free caps: B/W first {printLimits.freePagesPerSession} page(s), color first{' '}
            {printLimits.freeColorPagesPerSession} page(s), then paid rates apply. Global per-phone
            quota is set under Platform settings. Optional free-disabled window (e.g. 22:00–10:00)
            blocks all free pages at this kiosk during those Asia/Kolkata hours. Clear both times to
            disable the window.
          </p>
          <fieldset className="md:col-span-2 stack border-0 p-0 m-0">
            <legend className="muted">Home banners</legend>
            <label>
              <input
                type="checkbox"
                checked={printLimits.bannerHorizontalEnabled}
                onChange={(e) =>
                  setPrintLimits((s) => ({ ...s, bannerHorizontalEnabled: e.target.checked }))
                }
              />{' '}
              Show top / bottom banners
            </label>
            <label>
              <input
                type="checkbox"
                checked={printLimits.bannerVerticalEnabled}
                onChange={(e) =>
                  setPrintLimits((s) => ({ ...s, bannerVerticalEnabled: e.target.checked }))
                }
              />{' '}
              Show left / right banners
            </label>
          </fieldset>
          {settingsError ? <p className="error md:col-span-2">{settingsError}</p> : null}
        </form>
      </Modal>
    </div>
  );
}
