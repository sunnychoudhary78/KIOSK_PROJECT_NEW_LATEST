export type SurveillanceHealth = {
  state:
    | 'off'
    | 'recording'
    | 'paused_palm'
    | 'uploading'
    | 'camera_error'
    | 'storage_low'
    | 'stale'
    | 'offline';
  recording: boolean;
  lastSegmentAt?: string | null;
  lastSegmentBytes?: number | null;
  queuePending?: number;
  queueFailed?: number;
  oldestQueuedAt?: string | null;
  lastErrorCode?: string | null;
  lastErrorAt?: string | null;
  cameraName?: string | null;
};

export type DeviceSurveillanceView = {
  surveillanceEnabled: boolean;
  lastHeartbeatAt: string | null;
  surveillanceHealth?: SurveillanceHealth | null;
  surveillanceHealthAt?: string | null;
};

const HEARTBEAT_STALE_MS = 3 * 60 * 1000;

export type RecordingDisplayStatus = {
  key: string;
  label: string;
  className: string;
  title: string;
};

export function resolveRecordingDisplay(device: DeviceSurveillanceView): RecordingDisplayStatus {
  if (!device.surveillanceEnabled) {
    return {
      key: 'off',
      label: 'Off',
      className: 'text-muted-foreground',
      title: 'Surveillance is disabled for this kiosk',
    };
  }

  const heartbeatAt = device.lastHeartbeatAt ? Date.parse(device.lastHeartbeatAt) : NaN;
  const heartbeatFresh =
    Number.isFinite(heartbeatAt) && Date.now() - heartbeatAt <= HEARTBEAT_STALE_MS;

  if (!heartbeatFresh) {
    return {
      key: 'offline',
      label: 'Offline',
      className: 'text-muted-foreground',
      title: 'No recent heartbeat from this kiosk',
    };
  }

  const health = device.surveillanceHealth;
  if (!health) {
    return {
      key: 'stale',
      label: 'Unknown',
      className: 'text-amber-700',
      title: 'Waiting for surveillance health from kiosk',
    };
  }

  const queueNote =
    (health.queuePending ?? 0) > 0 ? ` · ${health.queuePending} pending upload` : '';
  const errorNote = health.lastErrorCode ? ` · ${health.lastErrorCode}` : '';

  switch (health.state) {
    case 'recording':
      return {
        key: 'recording',
        label: 'Recording',
        className: 'text-emerald-700',
        title: `Camera recording${queueNote}`,
      };
    case 'uploading':
      return {
        key: 'uploading',
        label: health.queuePending ? `Uploading (${health.queuePending})` : 'Uploading',
        className: 'text-amber-700',
        title: `Recording with upload backlog${queueNote}${errorNote}`,
      };
    case 'paused_palm':
      return {
        key: 'paused_palm',
        label: 'Paused',
        className: 'text-muted-foreground',
        title: 'Temporarily paused while palm camera is in use',
      };
    case 'camera_error':
      return {
        key: 'camera_error',
        label: 'Camera error',
        className: 'text-red-700',
        title: `Camera error${errorNote}. Kiosk will auto-retry.`,
      };
    case 'storage_low':
      return {
        key: 'storage_low',
        label: 'Storage low',
        className: 'text-red-700',
        title: `Local disk/cache limit reached${errorNote}`,
      };
    case 'stale':
      return {
        key: 'stale',
        label: 'Stale',
        className: 'text-amber-700',
        title: `Enabled but not actively recording${errorNote}`,
      };
    case 'offline':
      return {
        key: 'offline',
        label: 'Offline',
        className: 'text-muted-foreground',
        title: 'Kiosk reported offline',
      };
    case 'off':
    default:
      return {
        key: 'off',
        label: 'Off',
        className: 'text-muted-foreground',
        title: 'Surveillance is disabled',
      };
  }
}
