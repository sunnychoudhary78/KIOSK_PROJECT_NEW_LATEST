export type DevicePrintLimits = {
  maxPagesPerSession: number;
  freePagesPerSession: number;
  extraPageChargeRupees: number;
  freeColorPagesPerSession: number;
  extraColorPageChargeRupees: number;
};

export const DEFAULT_DEVICE_PRINT_LIMITS: DevicePrintLimits = {
  maxPagesPerSession: 10,
  freePagesPerSession: 5,
  extraPageChargeRupees: 10,
  freeColorPagesPerSession: 0,
  extraColorPageChargeRupees: 20,
};

export function printLimitsFromDevice(
  device: Partial<DevicePrintLimits> | null | undefined,
): DevicePrintLimits {
  return {
    maxPagesPerSession: device?.maxPagesPerSession ?? DEFAULT_DEVICE_PRINT_LIMITS.maxPagesPerSession,
    freePagesPerSession:
      device?.freePagesPerSession ?? DEFAULT_DEVICE_PRINT_LIMITS.freePagesPerSession,
    extraPageChargeRupees:
      device?.extraPageChargeRupees ?? DEFAULT_DEVICE_PRINT_LIMITS.extraPageChargeRupees,
    freeColorPagesPerSession:
      device?.freeColorPagesPerSession ?? DEFAULT_DEVICE_PRINT_LIMITS.freeColorPagesPerSession,
    extraColorPageChargeRupees:
      device?.extraColorPageChargeRupees ?? DEFAULT_DEVICE_PRINT_LIMITS.extraColorPageChargeRupees,
  };
}
