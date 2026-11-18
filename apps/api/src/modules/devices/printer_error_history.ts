export type PrinterErrorEntry = {
  index: number;
  description: string;
  firstSeenAt?: string;
  lastSeenAt?: string;
};

export type PrinterErrorAdminMeta = {
  hiddenSignature?: string | null;
  hiddenAt?: string | null;
};

type PrinterHealthLike = {
  errorHistory?: {
    available?: boolean;
    entries?: Array<{
      index?: number;
      description?: string;
      firstSeenAt?: string;
      lastSeenAt?: string;
    }>;
  };
  _admin?: PrinterErrorAdminMeta;
  [key: string]: unknown;
};

function normalizeEntries(
  raw: PrinterHealthLike['errorHistory'] | undefined,
): PrinterErrorEntry[] {
  if (!raw || raw.available !== true || !Array.isArray(raw.entries)) return [];
  const out: PrinterErrorEntry[] = [];
  for (const entry of raw.entries) {
    const index = entry?.index;
    const description = entry?.description?.trim();
    if (
      typeof index !== 'number' ||
      !Number.isInteger(index) ||
      index < 1 ||
      index > 10 ||
      !description
    ) {
      continue;
    }
    const normalized: PrinterErrorEntry = { index, description };
    if (typeof entry.firstSeenAt === 'string' && entry.firstSeenAt.length > 0) {
      normalized.firstSeenAt = entry.firstSeenAt;
    }
    if (typeof entry.lastSeenAt === 'string' && entry.lastSeenAt.length > 0) {
      normalized.lastSeenAt = entry.lastSeenAt;
    }
    out.push(normalized);
    if (out.length >= 10) break;
  }
  return out;
}

export function printerErrorSignature(entries: PrinterErrorEntry[]): string {
  return entries
    .map((entry) => `${entry.index}:${entry.description.trim().toLowerCase()}`)
    .sort()
    .join('|');
}

export function readPrinterErrorAdminMeta(health: unknown): PrinterErrorAdminMeta {
  if (!health || typeof health !== 'object') return {};
  const admin = (health as PrinterHealthLike)._admin;
  if (!admin || typeof admin !== 'object') return {};
  return {
    hiddenSignature: admin.hiddenSignature ?? null,
    hiddenAt: admin.hiddenAt ?? null,
  };
}

export function stripPrinterAdminMeta<T extends Record<string, unknown>>(health: T): T {
  if (!('_admin' in health)) return health;
  const { _admin: _ignored, ...rest } = health;
  return rest as T;
}

/** Keep firstSeenAt across heartbeats; refresh lastSeenAt. */
export function enrichPrinterHealthErrors(
  previousHealth: unknown,
  nextHealth: Record<string, unknown>,
  now: Date,
  previousHealthAt?: Date | null,
): Record<string, unknown> {
  const nowIso = now.toISOString();
  const fallbackFirstSeen =
    previousHealthAt && Number.isFinite(previousHealthAt.getTime())
      ? previousHealthAt.toISOString()
      : nowIso;
  const prev = previousHealth && typeof previousHealth === 'object'
    ? (previousHealth as PrinterHealthLike)
    : null;
  const prevEntries = normalizeEntries(prev?.errorHistory);
  const prevByKey = new Map(
    prevEntries.map((entry) => [`${entry.index}:${entry.description.trim().toLowerCase()}`, entry]),
  );

  const incoming = nextHealth as PrinterHealthLike;
  const nextEntries = normalizeEntries(incoming.errorHistory).map((entry) => {
    const key = `${entry.index}:${entry.description.trim().toLowerCase()}`;
    const prior = prevByKey.get(key);
    return {
      index: entry.index,
      description: entry.description,
      firstSeenAt:
        prior?.firstSeenAt ?? entry.firstSeenAt ?? (prior ? fallbackFirstSeen : nowIso),
      lastSeenAt: nowIso,
    };
  });

  const admin = readPrinterErrorAdminMeta(previousHealth);
  const signature = printerErrorSignature(nextEntries);
  const hiddenStill =
    admin.hiddenSignature &&
    admin.hiddenSignature.length > 0 &&
    admin.hiddenSignature === signature;

  const errorHistory = incoming.errorHistory;
  const next: Record<string, unknown> = {
    ...nextHealth,
    ...(errorHistory && typeof errorHistory === 'object'
      ? {
          errorHistory: {
            ...errorHistory,
            available: errorHistory.available === true,
            entries: nextEntries,
          },
        }
      : {}),
  };

  if (hiddenStill) {
    next._admin = {
      hiddenSignature: admin.hiddenSignature,
      hiddenAt: admin.hiddenAt ?? nowIso,
    };
  } else if (admin.hiddenSignature) {
    // Error set changed — auto-unhide.
    next._admin = {};
  }

  return next;
}

export function applyPrinterErrorsHidden(
  health: unknown,
  hidden: boolean,
  now: Date,
): Record<string, unknown> | null {
  if (!health || typeof health !== 'object') return null;
  const current = { ...(health as Record<string, unknown>) };
  const entries = normalizeEntries((health as PrinterHealthLike).errorHistory);
  if (!hidden) {
    current._admin = {};
    return current;
  }
  if (entries.length === 0) {
    current._admin = {};
    return current;
  }
  current._admin = {
    hiddenSignature: printerErrorSignature(entries),
    hiddenAt: now.toISOString(),
  };
  return current;
}

export function printerErrorsAreHidden(health: unknown): boolean {
  const admin = readPrinterErrorAdminMeta(health);
  if (!admin.hiddenSignature) return false;
  const entries = normalizeEntries(
    health && typeof health === 'object'
      ? (health as PrinterHealthLike).errorHistory
      : undefined,
  );
  return entries.length > 0 && printerErrorSignature(entries) === admin.hiddenSignature;
}

export function formatDurationShort(fromIso: string | undefined, to = Date.now()): string | null {
  if (!fromIso) return null;
  const from = Date.parse(fromIso);
  if (!Number.isFinite(from) || from > to) return null;
  const seconds = Math.floor((to - from) / 1000);
  if (seconds < 60) return `${Math.max(seconds, 0)}s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 48) {
    const remMin = minutes % 60;
    return remMin > 0 ? `${hours}h ${remMin}m` : `${hours}h`;
  }
  const days = Math.floor(hours / 24);
  return `${days}d`;
}
