import { z } from 'zod';

export const serviceOperationalStatuses = [
  'available',
  'under_maintenance',
  'out_of_service',
] as const;

export const serviceEnablementSchema = z.object({
  deviceId: z.string().uuid(),
  enabled: z.boolean(),
});

export type ServiceEnablementInput = z.infer<typeof serviceEnablementSchema>;

export const setServiceOperationalStatusSchema = z.object({
  status: z.enum(serviceOperationalStatuses),
});

export type SetServiceOperationalStatusInput = z.infer<
  typeof setServiceOperationalStatusSchema
>;
