import { z } from 'zod';

const eventKeySchema = z
  .string()
  .min(1)
  .max(120)
  .regex(/^[a-z0-9._-]+$/, 'eventKey must be lowercase dotted path');

export const reportServiceEventsSchema = z.object({
  events: z
    .array(
      z.object({
        eventKey: eventKeySchema,
        occurredAt: z.string().datetime().optional(),
        metadata: z.record(z.unknown()).optional(),
      }),
    )
    .min(1)
    .max(100),
});

export const serviceAnalyticsQuerySchema = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

export type ReportServiceEventsInput = z.infer<typeof reportServiceEventsSchema>;
export type ServiceAnalyticsQuery = z.infer<typeof serviceAnalyticsQuerySchema>;
