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

export const surveillanceHealthStates = [
  'off',
  'recording',
  'paused_palm',
  'uploading',
  'camera_error',
  'storage_low',
  'stale',
  'offline',
] as const;

export const surveillanceHealthSchema = z.object({
  state: z.enum(surveillanceHealthStates),
  recording: z.boolean(),
  lastSegmentAt: z.string().min(1).nullable().optional(),
  lastSegmentBytes: z.number().int().nonnegative().nullable().optional(),
  queuePending: z.number().int().nonnegative().optional(),
  queueFailed: z.number().int().nonnegative().optional(),
  oldestQueuedAt: z.string().min(1).nullable().optional(),
  lastErrorCode: z.string().max(64).nullable().optional(),
  lastErrorAt: z.string().min(1).nullable().optional(),
  cameraName: z.string().max(160).nullable().optional(),
});

export type SurveillanceHealthInput = z.infer<typeof surveillanceHealthSchema>;

export const printerHealthStates = [
  'ready',
  'printing',
  'jam',
  'paper_out',
  'toner_low',
  'offline',
  'error',
  'unknown',
] as const;

export const printerTraySchema = z.object({
  name: z.string().min(1).max(80),
  levelPercent: z.number().int().min(0).max(100).nullable().optional(),
  status: z.string().max(80).nullable().optional(),
});

export const printerSupplySchema = z.object({
  name: z.string().min(1).max(80),
  color: z.string().min(1).max(40),
  levelPercent: z.number().int().min(0).max(100).nullable().optional(),
  status: z.string().max(80).nullable().optional(),
});

const printerPercent = z.number().int().min(0).max(100).nullable().optional();
const printerCounter = z.number().int().nonnegative().nullable().optional();

export const printerMaintenanceSchema = z.object({
  available: z.boolean(),
  toner: z
    .object({
      blackPercent: printerPercent,
      cyanPercent: printerPercent,
      magentaPercent: printerPercent,
      yellowPercent: printerPercent,
    })
    .optional(),
  pages: z
    .object({
      total: printerCounter,
      color: printerCounter,
      blackAndWhite: printerCounter,
    })
    .optional(),
  parts: z
    .object({
      beltRemainingPages: printerCounter,
      fuserRemainingPages: printerCounter,
    })
    .optional(),
});

export const printerErrorHistorySchema = z.object({
  available: z.boolean(),
  entries: z
    .array(
      z.object({
        index: z.number().int().min(1).max(10),
        description: z.string().min(1).max(160),
      }),
    )
    .max(10)
    .optional(),
});

export const printerHealthSchema = z.object({
  state: z.enum(printerHealthStates),
  online: z.boolean(),
  printerName: z.string().max(160).nullable().optional(),
  model: z.string().max(120).nullable().optional(),
  trays: z.array(printerTraySchema).max(16).optional(),
  supplies: z.array(printerSupplySchema).max(16).optional(),
  maintenance: printerMaintenanceSchema.optional(),
  errorHistory: printerErrorHistorySchema.optional(),
  pageCounter: z.number().int().nonnegative().nullable().optional(),
  snmpOk: z.boolean().nullable().optional(),
  snmpReachable: z.boolean().nullable().optional(),
  consecutiveFailures: z.number().int().nonnegative().nullable().optional(),
  lastSuccessAt: z.string().min(1).nullable().optional(),
  lastPollError: z.string().max(200).nullable().optional(),
  hrPrinterStatus: z.number().int().nullable().optional(),
  hrPrinterStatusLabel: z.string().max(40).nullable().optional(),
  errorFlagsHex: z.string().max(16).nullable().optional(),
  noPaper: z.boolean().optional(),
  jammed: z.boolean().optional(),
  offlineBit: z.boolean().optional(),
  spoolerJobsQueued: z.number().int().nonnegative().nullable().optional(),
  spoolerJobsPrinting: z.number().int().nonnegative().nullable().optional(),
  lastErrorCode: z.string().max(64).nullable().optional(),
  lastErrorAt: z.string().min(1).nullable().optional(),
});

export type PrinterHealthInput = z.infer<typeof printerHealthSchema>;

export const deviceHeartbeatBodySchema = z
  .object({
    surveillance: surveillanceHealthSchema.optional(),
    printer: printerHealthSchema.optional(),
  })
  .default({});

export type DeviceHeartbeatBody = z.infer<typeof deviceHeartbeatBodySchema>;

const localTimeHmm = z
  .string()
  .regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Must be HH:mm in 24-hour format')
  .nullable();

export const setDevicePrintLimitsSchema = z
  .object({
    maxPagesPerSession: z.number().int().min(1).max(100),
    freePagesPerSession: z.number().int().min(0).max(100),
    extraPageChargeRupees: z.number().int().min(0).max(1000),
    freeColorPagesPerSession: z.number().int().min(0).max(100),
    extraColorPageChargeRupees: z.number().int().min(0).max(1000),
    freeDisabledFromLocal: localTimeHmm.optional(),
    freeDisabledToLocal: localTimeHmm.optional(),
    bannerHorizontalEnabled: z.boolean().optional(),
    bannerVerticalEnabled: z.boolean().optional(),
  })
  .refine((value) => value.freePagesPerSession <= value.maxPagesPerSession, {
    message: 'freePagesPerSession cannot exceed maxPagesPerSession',
    path: ['freePagesPerSession'],
  })
  .refine((value) => value.freeColorPagesPerSession <= value.maxPagesPerSession, {
    message: 'freeColorPagesPerSession cannot exceed maxPagesPerSession',
    path: ['freeColorPagesPerSession'],
  })
  .refine(
    (value) => {
      const from = value.freeDisabledFromLocal;
      const to = value.freeDisabledToLocal;
      const fromSet = from !== undefined && from !== null;
      const toSet = to !== undefined && to !== null;
      return fromSet === toSet;
    },
    {
      message: 'freeDisabledFromLocal and freeDisabledToLocal must both be set or both cleared',
      path: ['freeDisabledFromLocal'],
    },
  );

export type SetDevicePrintLimitsInput = z.infer<typeof setDevicePrintLimitsSchema>;
