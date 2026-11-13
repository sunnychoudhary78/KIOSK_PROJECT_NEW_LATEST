import { z } from 'zod';

export const DIAGNOSTIC_CATEGORIES = [
  'printer',
  'astrology',
  'well_being',
  'shutter',
  'cabinet_light',
  'charging',
  'serial',
  'app',
] as const;

export const DIAGNOSTIC_LEVELS = ['info', 'warn', 'error'] as const;

const eventSchema = z
  .string()
  .min(1)
  .max(120)
  .regex(/^[a-z0-9._-]+$/, 'event must be lowercase dotted path');

const metadataSchema = z
  .record(z.unknown())
  .optional()
  .refine(
    (value) => {
      if (value == null) return true;
      try {
        return JSON.stringify(value).length <= 8192;
      } catch {
        return false;
      }
    },
    { message: 'metadata must be at most 8KB when serialized' },
  );

export const reportDiagnosticLogsSchema = z.object({
  logs: z
    .array(
      z.object({
        level: z.enum(DIAGNOSTIC_LEVELS),
        category: z.enum(DIAGNOSTIC_CATEGORIES),
        event: eventSchema,
        message: z.string().min(1).max(500),
        occurredAt: z.string().datetime().optional(),
        correlationId: z.string().max(64).optional(),
        metadata: metadataSchema,
      }),
    )
    .min(1)
    .max(50),
});

export const listDiagnosticLogsQuerySchema = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  level: z.enum(DIAGNOSTIC_LEVELS).optional(),
  /** Comma-separated levels, e.g. error,warn */
  levels: z.string().optional(),
  category: z.enum(DIAGNOSTIC_CATEGORIES).optional(),
  limit: z.coerce.number().int().min(1).max(200).optional(),
  /** Cursor: ISO occurredAt for keyset pagination (fetch older than this). */
  before: z.string().datetime().optional(),
  beforeId: z.string().uuid().optional(),
});

export type ReportDiagnosticLogsInput = z.infer<typeof reportDiagnosticLogsSchema>;
export type ListDiagnosticLogsQuery = z.infer<typeof listDiagnosticLogsQuerySchema>;

export type DiagnosticLevel = (typeof DIAGNOSTIC_LEVELS)[number];

export function parseLevelsCsv(
  raw: string | undefined,
): DiagnosticLevel[] | undefined {
  if (raw == null || raw.trim() === '') return undefined;
  const parts = raw.split(',').map((p) => p.trim()).filter(Boolean);
  const allowed = new Set<string>(DIAGNOSTIC_LEVELS);
  const out: DiagnosticLevel[] = [];
  for (const part of parts) {
    if (!allowed.has(part)) {
      throw new Error(`Invalid level: ${part}`);
    }
    out.push(part as DiagnosticLevel);
  }
  return out.length > 0 ? out : undefined;
}
