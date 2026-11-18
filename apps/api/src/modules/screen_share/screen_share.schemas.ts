import { z } from 'zod';

export const screenShareAckBodySchema = z.object({
  sessionId: z.string().uuid(),
  result: z.enum(['started', 'failed', 'ended']),
  error: z.string().max(500).optional(),
});

export type ScreenShareAckBody = z.infer<typeof screenShareAckBodySchema>;
