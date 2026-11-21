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
  queueDue?: number;
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

/** Warn in admin when kiosk backlog reaches this many pending clips. */
export const UPLOAD_BACKLOG_WARN_PENDING = 10;

/** Warn in admin when oldest pending clip is at least this old. */
export const UPLOAD_BACKLOG_WARN_AGE_MS = 60 * 60 * 1000;

export type RecordingDisplayStatus = {
  key: string;
  label: string;
  className: string;
  title: string;
};

export type UploadBacklogWarning = {
  warn: boolean;
  pending: number;
  oldestQueuedAt: string | null;
  ageLabel: string | null;
  lastErrorCode: string | null;
};

export function formatQueueAge(oldestQueuedAt: string | null | undefined, now = Date.now()): string | null {
  if (!oldestQueuedAt) return null;
  const ts = Date.parse(oldestQueuedAt);
  if (!Number.isFinite(ts)) return null;
  const ageMs = Math.max(0, now - ts);
  const minutes = Math.floor(ageMs / 60000);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const rem = minutes % 60;
  return rem > 0 ? `${hours}h ${rem}m` : `${hours}h`;
}

/** True when queuePending >= 10 or oldest queued age >= 1h. */
export function resolveUploadBacklogWarning(
  health: SurveillanceHealth | null | undefined,
  now = Date.now(),
): UploadBacklogWarning {
  const pending = health?.queuePending ?? 0;
  const oldestQueuedAt = health?.oldestQueuedAt ?? null;
  const lastErrorCode = health?.lastErrorCode ?? null;
  const oldestTs = oldestQueuedAt ? Date.parse(oldestQueuedAt) : NaN;
  const ageMs = Number.isFinite(oldestTs) ? Math.max(0, now - oldestTs) : 0;
  const warn =
    pending >= UPLOAD_BACKLOG_WARN_PENDING ||
    (pending > 0 && ageMs >= UPLOAD_BACKLOG_WARN_AGE_MS);
  return {
    warn,
    pending,
    oldestQueuedAt,
    ageLabel: pending > 0 ? formatQueueAge(oldestQueuedAt, now) : null,
    lastErrorCode,
  };
}

export type SurveillanceQueueCommandType = 'heal_queue' | 'retry_uploads' | 'prune_stubs';

export const SURVEILLANCE_QUEUE_ACTIONS: {
  type: SurveillanceQueueCommandType;
  label: string;
  description: string;
}[] = [
  {
    type: 'heal_queue',
    label: 'Unstick queue',
    description: 'Reset upload schedules so pending clips are tried now',
  },
  {
    type: 'retry_uploads',
    label: 'Retry uploads',
    description: 'Re-queue failed uploads (size_mismatch, network, etc.)',
  },
  {
    type: 'prune_stubs',
    label: 'Clear stub clips',
    description: 'Remove empty invalid_segment junk from the local queue',
  },
];

export function labelForQueueCommand(type: SurveillanceQueueCommandType): string {
  return SURVEILLANCE_QUEUE_ACTIONS.find((action) => action.type === type)?.label ?? type;
}

/**
 * Picks the best Phase-1 maintenance action from live health.
 * Priority: stuck schedule → stub poison → upload failures/backlog.
 */
export function resolveRecommendedQueueAction(
  health: SurveillanceHealth | null | undefined,
): SurveillanceQueueCommandType | null {
  if (!health) return null;
  const pending = health.queuePending ?? 0;
  const due = health.queueDue;
  const failed = health.queueFailed ?? 0;
  const error = health.lastErrorCode ?? '';

  if (pending > 0 && due === 0) {
    return 'heal_queue';
  }
  if (error === 'invalid_segment') {
    return 'prune_stubs';
  }
  if (
    error === 'size_mismatch' ||
    error === 'upload_incomplete' ||
    error === 'unauthorized' ||
    error === 'upload_failed' ||
    error === 'upload_timeout' ||
    failed > 0 ||
    resolveUploadBacklogWarning(health).warn
  ) {
    return 'retry_uploads';
  }
  return null;
}

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

  const backlog = resolveUploadBacklogWarning(health);
  const ageNote = backlog.ageLabel ? ` · oldest ${backlog.ageLabel}` : '';
  const queueNote =
    (health.queuePending ?? 0) > 0 ? ` · ${health.queuePending} pending upload${ageNote}` : '';
  const errorNote = health.lastErrorCode ? ` · ${health.lastErrorCode}` : '';
  const backlogClass = backlog.warn ? 'text-red-700' : 'text-amber-700';

  switch (health.state) {
    case 'recording':
      return {
        key: 'recording',
        label: backlog.warn
          ? `Recording · backlog (${health.queuePending})`
          : 'Recording',
        className: backlog.warn ? backlogClass : 'text-emerald-700',
        title: `Camera recording${queueNote}${errorNote}`,
      };
    case 'uploading': {
      const pending = health.queuePending ?? 0;
      const due = health.queueDue;
      if (pending > 0 && due === 0) {
        return {
          key: 'queue_stuck',
          label: 'Queue stuck',
          className: 'text-amber-700',
          title: `Local upload queue has ${pending} pending with none due${errorNote}`,
        };
      }
      return {
        key: 'uploading',
        label: pending
          ? backlog.warn
            ? `Backlog (${pending})`
            : `Uploading (${pending})`
          : 'Uploading',
        className: backlogClass,
        title: `Upload backlog${queueNote}${errorNote}`,
      };
    }
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
