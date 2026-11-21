import { z } from 'zod';

export const surveillanceCommandTypeSchema = z.enum([
  'heal_queue',
  'retry_uploads',
  'prune_stubs',
  'restart_recording',
  'flush_queue',
]);

export const createSurveillanceCommandBodySchema = z.object({
  type: surveillanceCommandTypeSchema,
});

export const surveillanceCommandAckBodySchema = z.object({
  ok: z.boolean(),
  result: z.record(z.unknown()).optional(),
  error: z.string().max(500).optional(),
});

export type CreateSurveillanceCommandBody = z.infer<typeof createSurveillanceCommandBodySchema>;
export type SurveillanceCommandAckBody = z.infer<typeof surveillanceCommandAckBodySchema>;
export type SurveillanceCommandType = z.infer<typeof surveillanceCommandTypeSchema>;
