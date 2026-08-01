import { z } from 'zod';

export const serviceEnablementSchema = z.object({
  deviceId: z.string().uuid(),
  enabled: z.boolean(),
});

export type ServiceEnablementInput = z.infer<typeof serviceEnablementSchema>;
