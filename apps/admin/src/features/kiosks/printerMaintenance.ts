export type PrinterMaintenanceToner = {
  blackPercent?: number | null;
  cyanPercent?: number | null;
  magentaPercent?: number | null;
  yellowPercent?: number | null;
};

export type PrinterMaintenancePages = {
  total?: number | null;
  color?: number | null;
  blackAndWhite?: number | null;
};

export type PrinterMaintenanceParts = {
  beltRemainingPages?: number | null;
  fuserRemainingPages?: number | null;
};

export type PrinterMaintenance = {
  available?: boolean | null;
  toner?: PrinterMaintenanceToner | null;
  pages?: PrinterMaintenancePages | null;
  parts?: PrinterMaintenanceParts | null;
};

export type PrinterHealthView = {
  state?: string | null;
  snmpOk?: boolean | null;
  lastSuccessAt?: string | null;
  maintenance?: PrinterMaintenance | null;
  errorHistory?: PrinterErrorHistory | null;
};

export type PrinterErrorHistoryEntry = {
  index?: number | null;
  description?: string | null;
};

export type PrinterErrorHistory = {
  available?: boolean | null;
  entries?: PrinterErrorHistoryEntry[] | null;
};

export type ErrorHistoryDisplay =
  | { status: 'unavailable' }
  | { status: 'empty' }
  | {
      status: 'current' | 'stale';
      title?: string;
      entries: { index: number; description: string }[];
    };

export type MaintenanceMetricLines = {
  toner: {
    black: string;
    cyan: string;
    magenta: string;
    yellow: string;
  };
  pages: {
    total: string;
    color: string;
    blackAndWhite: string;
  };
  parts: {
    belt: string;
    fuser: string;
  };
};

export type MaintenanceDisplay =
  | { status: 'unavailable' }
  | ({
      status: 'current' | 'stale';
      title?: string;
    } & MaintenanceMetricLines);

export type PrinterRowTone = 'muted' | 'ok' | 'amber' | 'alert';

export type PrinterRowSummary = {
  label: string;
  tone: PrinterRowTone;
};

export type PrinterStatusKind =
  | 'ready'
  | 'printing'
  | 'paper_out'
  | 'jam'
  | 'toner_low'
  | 'offline'
  | 'error'
  | 'unavailable';

export type PrinterStatusDisplay = {
  label: string;
  kind: PrinterStatusKind;
  fault: boolean;
};

const MISSING = '—';

function formatPercent(value: number | null | undefined): string {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0 || value > 100) {
    return MISSING;
  }
  return `${value}%`;
}

function formatCount(value: number | null | undefined): string {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
    return MISSING;
  }
  return value.toLocaleString();
}

function metricLines(maintenance: PrinterMaintenance): MaintenanceMetricLines {
  return {
    toner: {
      black: formatPercent(maintenance.toner?.blackPercent),
      cyan: formatPercent(maintenance.toner?.cyanPercent),
      magenta: formatPercent(maintenance.toner?.magentaPercent),
      yellow: formatPercent(maintenance.toner?.yellowPercent),
    },
    pages: {
      total: formatCount(maintenance.pages?.total),
      color: formatCount(maintenance.pages?.color),
      blackAndWhite: formatCount(maintenance.pages?.blackAndWhite),
    },
    parts: {
      belt: formatCount(maintenance.parts?.beltRemainingPages),
      fuser: formatCount(maintenance.parts?.fuserRemainingPages),
    },
  };
}

export function resolvePrinterMaintenance(
  health: PrinterHealthView | null | undefined,
): MaintenanceDisplay {
  const maintenance = health?.maintenance;
  if (!maintenance || maintenance.available !== true) {
    return { status: 'unavailable' };
  }

  const lines = metricLines(maintenance);
  if (health?.snmpOk === false) {
    const parsed = health.lastSuccessAt ? Date.parse(health.lastSuccessAt) : NaN;
    const title = Number.isFinite(parsed)
      ? `Last successful SNMP poll ${new Date(parsed).toLocaleString()}`
      : undefined;
    return { status: 'stale', title, ...lines };
  }

  return { status: 'current', ...lines };
}

function errorEntries(history: PrinterErrorHistory): { index: number; description: string }[] {
  return (history.entries ?? [])
    .filter((entry): entry is PrinterErrorHistoryEntry => {
      const index = entry?.index;
      const description = entry?.description;
      return (
        typeof index === 'number' &&
        Number.isInteger(index) &&
        index >= 1 &&
        index <= 10 &&
        typeof description === 'string' &&
        description.trim().length > 0
      );
    })
    .slice(0, 10)
    .map((entry) => ({
      index: entry.index as number,
      description: (entry.description as string).trim(),
    }));
}

export function resolvePrinterErrorHistory(
  health: PrinterHealthView | null | undefined,
): ErrorHistoryDisplay {
  const history = health?.errorHistory;
  if (!history || history.available !== true) {
    return { status: 'unavailable' };
  }
  const entries = errorEntries(history);
  if (health?.snmpOk === false) {
    const parsed = health.lastSuccessAt ? Date.parse(health.lastSuccessAt) : NaN;
    return {
      status: 'stale',
      entries,
      title: Number.isFinite(parsed)
        ? `Last successful SNMP poll ${new Date(parsed).toLocaleString()}`
        : undefined,
    };
  }
  if (entries.length === 0) {
    return { status: 'empty' };
  }
  return { status: 'current', entries };
}

const PRINTER_STATUS_LABELS: Record<Exclude<PrinterStatusKind, 'unavailable'>, string> = {
  ready: 'Ready',
  printing: 'Printing',
  paper_out: 'Out of paper',
  jam: 'Paper jam',
  toner_low: 'Toner low',
  offline: 'Offline',
  error: 'Error',
};

const PRINTER_FAULTS = new Set<PrinterStatusKind>([
  'paper_out',
  'jam',
  'toner_low',
  'offline',
  'error',
]);

export function resolvePrinterStatus(
  health: PrinterHealthView | null | undefined,
): PrinterStatusDisplay {
  const state = health?.state;
  if (state && state in PRINTER_STATUS_LABELS) {
    const kind = state as Exclude<PrinterStatusKind, 'unavailable'>;
    return {
      label: PRINTER_STATUS_LABELS[kind],
      kind,
      fault: PRINTER_FAULTS.has(kind),
    };
  }
  return { label: 'Unavailable', kind: 'unavailable', fault: false };
}

export function resolvePrinterRowSummary(
  health: PrinterHealthView | null | undefined,
): PrinterRowSummary {
  const maintenance = resolvePrinterMaintenance(health);
  const errors = resolvePrinterErrorHistory(health);
  const status = resolvePrinterStatus(health);
  const stale = maintenance.status === 'stale' || errors.status === 'stale';
  const recorded =
    errors.status === 'current' || errors.status === 'stale' ? errors.entries.length : 0;

  if (status.fault) {
    return { label: status.label, tone: health?.snmpOk === false ? 'amber' : 'alert' };
  }
  if (recorded > 0) {
    return {
      label: recorded === 1 ? '1 error' : `${recorded} errors`,
      tone: stale ? 'amber' : 'alert',
    };
  }
  if (stale) {
    return { label: 'Stale', tone: 'amber' };
  }
  if (maintenance.status === 'current') {
    if (status.kind === 'ready' || status.kind === 'printing') {
      return { label: status.label, tone: 'ok' };
    }
    return { label: 'OK', tone: 'ok' };
  }
  return { label: 'Unavailable', tone: 'muted' };
}
