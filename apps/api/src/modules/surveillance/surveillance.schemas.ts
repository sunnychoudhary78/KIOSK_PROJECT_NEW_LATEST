import { z } from 'zod';
import { MIN_SURVEILLANCE_SEGMENT_BYTES } from './surveillance.constants.js';

export const uploadUrlBodySchema = z.object({
  filename: z
    .string()
    .min(1)
    .max(128)
    .regex(/^[A-Za-z0-9._-]+\.mp4$/i, 'filename must be a simple .mp4 basename'),
  bytes: z.number().int().min(MIN_SURVEILLANCE_SEGMENT_BYTES).max(5_000_000_000),
  contentType: z.literal('video/mp4').default('video/mp4'),
  recordedOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
});

export type UploadUrlBody = z.infer<typeof uploadUrlBodySchema>;

export const listSegmentsQuerySchema = z.object({
  recordedOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  status: z.enum(['uploaded', 'pending_upload', 'all']).default('all'),
});

export type ListSegmentsQuery = z.infer<typeof listSegmentsQuerySchema>;
