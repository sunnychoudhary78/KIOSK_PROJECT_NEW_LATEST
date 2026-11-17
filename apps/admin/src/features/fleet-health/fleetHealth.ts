import {
  resolveRecordingDisplay,
  type SurveillanceHealth,
} from '../surveillance/surveillanceStatus';

export const HEARTBEAT_STALE_MS = 3 * 60 * 1000;

export type ComponentTone = 'ok' | 'warn' | 'error' | 'offline' | 'unknown';

export type ComponentStatus = {
  key: string;
  label: string;
  detail?: string;
  tone: ComponentTone;
};

export type PrinterHealth = {
  state?: string;
  online?: boolean | null;
  printerName?: string | null;
  model?: string | null;
  snmpOk?: boolean | null;
  snmpReachable?: boolean | null;
  noPaper?: boolean;
  jammed?: boolean;
  offlineBit?: boolean;
  consecutiveFailures?: number | null;
  lastSuccessAt?: string | null;
  lastPollError?: string | null;
  lastErrorCode?: string | null;
  lastErrorAt?: string | null;
  hrPrinterStatusLabel?: string | null;
  spoolerJobsQueued?: number | null;
  spoolerJobsPrinting?: number | null;
  maintenance?: {
    available?: boolean | null;
    toner?: {
      blackPercent?: number | null;
      cyanPercent?: number | null;
      magentaPercent?: number | null;
      yellowPercent?: number | null;
    };
    pages?: {
      total?: number | null;
      color?: number | null;
      blackAndWhite?: number | null;
    };
  };
  errorHistory?: {
    available?: boolean | null;
    entries?: Array<{ index?: number | null; description?: string | null }> | null;
  } | null;
};

export type HardwareHealth = {
  serial?: {
    status?: string;
    portName?: string | null;
    lastError?: string | null;
  };
  shutter?: {
    status?: string;
    pendingCommand?: string | null;
    lastError?: string | null;
  };
  cabinetLight?: {
    status?: string;
    on?: boolean | null;
    lastError?: string | null;
  };
  charging?: {
    status?: string;
    sensorOk?: boolean | null;
    phase?: string | null;
    lastError?: string | null;
  };
  sensors?: {
    status?: string;
    max30102?: string;
    mlx90614?: string;
    lastError?: string | null;
  };
};

export type FleetDevice = {
  id: string;
  name: string;
  siteName: string;
  status: string;
  deviceKey?: string;
  address?: string | null;
  lastHeartbeatAt: string | null;
  reportedAppVersion?: string | null;
  activeAppVersion?: string | null;
  surveillanceEnabled: boolean;
  surveillanceHealth?: SurveillanceHealth | null;
  surveillanceHealthAt?: string | null;
  printerHealth?: PrinterHealth | null;
  printerHealthAt?: string | null;
  hardwareHealth?: HardwareHealth | null;
  hardwareHealthAt?: string | null;
  printingPausedReason?: string | null;
  shutterCommand?: string | null;
  shutterCommandRequestedAt?: string | null;
  pagesLeft?: number | null;
  trayReserved?: number | null;
  trayAvailable?: number | null;
};

export function printerErrorEntries(
  health: PrinterHealth | null | undefined,
): { index: number; description: string }[] {
  if (health?.errorHistory?.available !== true) return [];
  return (health.errorHistory.entries ?? [])
    .filter((entry): entry is { index: number; description: string } => {
      const index = entry?.index;
      const description = entry?.description;
      return (
        typeof index === 'number' &&
        Number.isInteger(index) &&
        index >= 1 &&
        typeof description === 'string' &&
        description.trim().length > 0
      );
    })
    .map((entry) => ({
      index: entry.index,
      description: entry.description.trim(),
    }));
}

export type FleetDeviceRow = {
  device: FleetDevice;
  online: boolean;
  overall: ComponentTone;
  connectivity: ComponentStatus;
  printer: ComponentStatus;
  camera: ComponentStatus;
  controller: ComponentStatus;
  shutter: ComponentStatus;
  light: ComponentStatus;
  charging: ComponentStatus;
  sensors: ComponentStatus;
  app: ComponentStatus;
};

function toneFromHardware(status?: string | null): ComponentTone {
  switch (status) {
    case 'ok':
    case 'connected':
      return 'ok';
    case 'warn':
    case 'connecting':
    case 'reconnecting':
      return 'warn';
    case 'error':
      return 'error';
    case 'offline':
    case 'disconnected':
      return 'offline';
    default:
      return 'unknown';
  }
}

function worstTone(tones: ComponentTone[]): ComponentTone {
  const rank: Record<ComponentTone, number> = {
    error: 0,
    offline: 1,
    warn: 2,
    unknown: 3,
    ok: 4,
  };
  return tones.reduce((best, tone) => (rank[tone] < rank[best] ? tone : best), 'ok');
}

export function isDeviceOnline(device: FleetDevice, now = Date.now()): boolean {
  if (device.status === 'inactive') return false;
  if (!device.lastHeartbeatAt) return false;
  const at = Date.parse(device.lastHeartbeatAt);
  return Number.isFinite(at) && now - at <= HEARTBEAT_STALE_MS;
}

export function buildFleetRow(device: FleetDevice, now = Date.now()): FleetDeviceRow {
  const online = isDeviceOnline(device, now);
  const hw = device.hardwareHealth;

  const connectivity: ComponentStatus = !online
    ? {
        key: 'offline',
        label: device.status === 'inactive' ? 'Stopped' : 'Offline',
        detail: device.lastHeartbeatAt
          ? `Last seen ${new Date(device.lastHeartbeatAt).toLocaleString()}`
          : 'No heartbeat yet',
        tone: device.status === 'inactive' ? 'offline' : 'error',
      }
    : {
        key: 'online',
        label: 'Online',
        detail: device.lastHeartbeatAt
          ? `Heartbeat ${new Date(device.lastHeartbeatAt).toLocaleString()}`
          : undefined,
        tone: 'ok',
      };

  const printerHealth = device.printerHealth;
  let printer: ComponentStatus;
  if (!online) {
    printer = { key: 'offline', label: 'Offline', tone: 'offline' };
  } else if (device.printingPausedReason) {
    printer = {
      key: 'paused',
      label: 'Paused',
      detail: device.printingPausedReason.replace(/_/g, ' '),
      tone: 'error',
    };
  } else if (!printerHealth) {
    printer = { key: 'unknown', label: 'Unknown', tone: 'unknown' };
  } else {
    const state = printerHealth.state ?? 'unknown';
    const errors = printerErrorEntries(printerHealth);
    const bad =
      state === 'paper_out' ||
      state === 'jam' ||
      state === 'error' ||
      state === 'offline' ||
      printerHealth.noPaper ||
      printerHealth.jammed;
    const warn =
      state === 'toner_low' ||
      printerHealth.snmpReachable === false ||
      (!bad && errors.length > 0);
    const errorDetail =
      errors.length === 0
        ? undefined
        : errors.length === 1
          ? errors[0].description
          : `${errors.length} errors · ${errors[0].description}`;
    printer = {
      key: state,
      label:
        !bad && errors.length > 0
          ? errors.length === 1
            ? '1 error'
            : `${errors.length} errors`
          : state.replace(/_/g, ' '),
      detail: errorDetail ?? printerHealth.lastPollError ?? undefined,
      tone: bad ? 'error' : warn ? 'warn' : state === 'unknown' ? 'unknown' : 'ok',
    };
  }

  const recording = resolveRecordingDisplay(device);
  const camera: ComponentStatus = {
    key: recording.key,
    label: recording.label,
    detail: recording.title,
    tone:
      recording.key === 'camera_error' || recording.key === 'storage_low'
        ? 'error'
        : recording.key === 'offline' || recording.key === 'off'
          ? 'offline'
          : recording.key === 'stale' || recording.key === 'unknown'
            ? 'unknown'
            : recording.key === 'paused_palm' || recording.key === 'uploading'
              ? 'warn'
              : 'ok',
  };

  const controller: ComponentStatus = !online
    ? { key: 'offline', label: 'Offline', tone: 'offline' }
    : hw?.serial
      ? {
          key: hw.serial.status ?? 'unknown',
          label: (hw.serial.status ?? 'unknown').replace(/_/g, ' '),
          detail: hw.serial.portName
            ? `Port ${hw.serial.portName}`
            : hw.serial.lastError ?? undefined,
          tone: toneFromHardware(hw.serial.status),
        }
      : { key: 'unknown', label: 'Not reported', tone: 'unknown' };

  const shutter: ComponentStatus = !online
    ? { key: 'offline', label: 'Offline', tone: 'offline' }
    : {
        key: hw?.shutter?.status ?? (device.shutterCommand ? 'pending' : 'unknown'),
        label: device.shutterCommand
          ? `Pending ${device.shutterCommand}`
          : (hw?.shutter?.status ?? 'unknown').replace(/_/g, ' '),
        detail: hw?.shutter?.lastError ?? undefined,
        tone: device.shutterCommand
          ? 'warn'
          : toneFromHardware(hw?.shutter?.status),
      };

  const light: ComponentStatus = !online
    ? { key: 'offline', label: 'Offline', tone: 'offline' }
    : {
        key: hw?.cabinetLight?.status ?? 'unknown',
        label: (hw?.cabinetLight?.status ?? 'not reported').replace(/_/g, ' '),
        detail:
          hw?.cabinetLight?.on == null
            ? hw?.cabinetLight?.lastError ?? undefined
            : hw.cabinetLight.on
              ? 'Relay on'
              : 'Relay off',
        tone: toneFromHardware(hw?.cabinetLight?.status),
      };

  const charging: ComponentStatus = !online
    ? { key: 'offline', label: 'Offline', tone: 'offline' }
    : {
        key: hw?.charging?.status ?? 'unknown',
        label: (hw?.charging?.status ?? 'not reported').replace(/_/g, ' '),
        detail:
          hw?.charging?.phase ??
          (hw?.charging?.sensorOk === false ? 'Sensor lost' : hw?.charging?.lastError ?? undefined),
        tone: toneFromHardware(hw?.charging?.status),
      };

  const sensors: ComponentStatus = !online
    ? { key: 'offline', label: 'Offline', tone: 'offline' }
    : {
        key: hw?.sensors?.status ?? 'unknown',
        label: (hw?.sensors?.status ?? 'not reported').replace(/_/g, ' '),
        detail: [
          hw?.sensors?.max30102 ? `SpO₂ ${hw.sensors.max30102}` : null,
          hw?.sensors?.mlx90614 ? `Temp ${hw.sensors.mlx90614}` : null,
          hw?.sensors?.lastError,
        ]
          .filter(Boolean)
          .join(' · ') || undefined,
        tone: toneFromHardware(hw?.sensors?.status),
      };

  const appBehind =
    device.reportedAppVersion &&
    device.activeAppVersion &&
    device.reportedAppVersion !== device.activeAppVersion;
  const app: ComponentStatus = {
    key: appBehind ? 'behind' : device.reportedAppVersion ? 'ok' : 'unknown',
    label: device.reportedAppVersion ?? 'Unknown',
    detail: appBehind
      ? `Live target ${device.activeAppVersion}`
      : device.activeAppVersion
        ? 'Up to date'
        : undefined,
    tone: appBehind ? 'warn' : device.reportedAppVersion ? 'ok' : 'unknown',
  };

  const overall = worstTone([
    connectivity.tone,
    printer.tone,
    camera.tone,
    controller.tone,
    shutter.tone,
    light.tone,
    charging.tone,
    sensors.tone,
    app.tone,
  ]);

  return {
    device,
    online,
    overall,
    connectivity,
    printer,
    camera,
    controller,
    shutter,
    light,
    charging,
    sensors,
    app,
  };
}

export function summarizeFleet(rows: FleetDeviceRow[]) {
  const total = rows.length;
  const online = rows.filter((r) => r.online).length;
  const unhealthy = rows.filter((r) => r.overall === 'error' || r.overall === 'offline').length;
  const warn = rows.filter((r) => r.overall === 'warn').length;
  const printerFaults = rows.filter((r) => r.printer.tone === 'error').length;
  const cameraFaults = rows.filter((r) => r.camera.tone === 'error').length;
  const controllerFaults = rows.filter(
    (r) => r.controller.tone === 'error' || r.controller.tone === 'offline',
  ).length;
  const versionLag = rows.filter((r) => r.app.key === 'behind').length;
  return {
    total,
    online,
    offline: total - online,
    unhealthy,
    warn,
    printerFaults,
    cameraFaults,
    controllerFaults,
    versionLag,
  };
}
