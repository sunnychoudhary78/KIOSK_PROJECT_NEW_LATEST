import { z } from 'zod';

export const registerDeviceSchema = z.object({
  name: z.string().min(2).max(120),
  siteName: z.string().min(2).max(120),
  tenantId: z.string().uuid().optional(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  address: z.string().trim().max(240).optional(),
});

export type RegisterDeviceInput = z.infer<typeof registerDeviceSchema>;

export const nearbyDevicesQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export type NearbyDevicesQuery = z.infer<typeof nearbyDevicesQuerySchema>;

export const setDeviceStatusSchema = z.object({
  status: z.enum(['active', 'inactive']),
});

export type SetDeviceStatusInput = z.infer<typeof setDeviceStatusSchema>;

export const setDeviceSurveillanceSchema = z.object({
  enabled: z.boolean(),
});

export type SetDeviceSurveillanceInput = z.infer<typeof setDeviceSurveillanceSchema>;

export const setDevicePrintLimitsSchema = z
  .object({
    maxPagesPerSession: z.number().int().min(1).max(100),
    freePagesPerSession: z.number().int().min(0).max(100),
    extraPageChargeRupees: z.number().int().min(0).max(1000),
    freeColorPagesPerSession: z.number().int().min(0).max(100),
    extraColorPageChargeRupees: z.number().int().min(0).max(1000),
  })
  .refine((value) => value.freePagesPerSession <= value.maxPagesPerSession, {
    message: 'freePagesPerSession cannot exceed maxPagesPerSession',
    path: ['freePagesPerSession'],
  })
  .refine((value) => value.freeColorPagesPerSession <= value.maxPagesPerSession, {
    message: 'freeColorPagesPerSession cannot exceed maxPagesPerSession',
    path: ['freeColorPagesPerSession'],
  });

export type SetDevicePrintLimitsInput = z.infer<typeof setDevicePrintLimitsSchema>;
