import { z } from 'zod';

const serviceKeySchema = z
  .string()
  .min(1)
  .max(120)
  .regex(/^[a-z0-9._-]+$/, 'serviceKey must be lowercase dotted path');

export const reportServiceRatingsSchema = z.object({
  ratings: z
    .array(
      z.object({
        serviceKey: serviceKeySchema,
        stars: z.number().int().min(1).max(5),
        occurredAt: z.string().datetime().optional(),
        metadata: z.record(z.unknown()).optional(),
      }),
    )
    .min(1)
    .max(20),
});

export const serviceRatingsQuerySchema = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

export type ReportServiceRatingsInput = z.infer<typeof reportServiceRatingsSchema>;
export type ServiceRatingsQuery = z.infer<typeof serviceRatingsQuerySchema>;
