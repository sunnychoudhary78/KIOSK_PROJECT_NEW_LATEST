import { randomBytes } from 'node:crypto';
import bcrypt from 'bcryptjs';
import { DeviceStatus } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import {
  PRINTING_PAUSED_PAPER_OUT,
  printerReportsPaperOut,
} from '../printing/printing_pause.js';
import { haversineKm, roundDistanceKm } from '../../shared/geo.js';
import type { AuditService } from '../audit/audit.service.js';
import type {
  DeviceHeartbeatBody,
  NearbyDevicesQuery,
  PrinterHealthInput,
  RegisterDeviceInput,
  SetDevicePrintLimitsInput,
  SetPrinterTrayInput,
  SurveillanceHealthInput,
} from './devices.schemas.js';
import { applyTrayLoad, pagesLeft, usbPagesTotal } from './printer_tray.js';
import { isWithinLocalTimeWindow } from '../print_quota/print_quota.time.js';
import { printLimitsFromDevice } from './device_print_limits.js';

function mapSurveillanceHealth(value: unknown): SurveillanceHealthInput | null {
  if (value == null || typeof value !== 'object') {
    return null;
  }
  return value as SurveillanceHealthInput;
}

function mapPrinterHealth(value: unknown): PrinterHealthInput | null {
  if (value == null || typeof value !== 'object') {
    return null;
  }
  return value as PrinterHealthInput;
}

function ackMatchesRefresh(stored: Date | null | undefined, ack: string | undefined): boolean {
  if (!stored || !ack) return false;
  const parsed = Date.parse(ack);
  return Number.isFinite(parsed) && stored.getTime() === parsed;
}

function mapDevice(device: {
  id: string;
  name: string;
  deviceKey: string;
  status: DeviceStatus;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  lastHeartbeatAt: Date | null;
  surveillanceEnabled: boolean;
  surveillanceHealth?: unknown;
  surveillanceHealthAt?: Date | null;
  printerHealth?: unknown;
  printerHealthAt?: Date | null;
  printerRefreshRequestedAt?: Date | null;
  printingPausedReason?: string | null;
  maxPagesPerSession?: number;
  freePagesPerSession?: number;
  extraPageChargeRupees?: number;
  freeColorPagesPerSession?: number;
  extraColorPageChargeRupees?: number;
  freeDisabledFromLocal?: string | null;
  freeDisabledToLocal?: string | null;
  bannerHorizontalEnabled?: boolean;
  bannerVerticalEnabled?: boolean;
  trayPages?: number | null;
  trayBaselinePages?: number | null;
  site: { name: string };
}) {
  return {
    id: device.id,
    name: device.name,
    deviceKey: device.deviceKey,
    status: device.status,
    siteName: device.site.name,
    latitude: device.latitude,
    longitude: device.longitude,
    address: device.address,
    lastHeartbeatAt: device.lastHeartbeatAt?.toISOString() ?? null,
    surveillanceEnabled: device.surveillanceEnabled,
    surveillanceHealth: mapSurveillanceHealth(device.surveillanceHealth),
    surveillanceHealthAt: device.surveillanceHealthAt?.toISOString() ?? null,
    printerHealth: mapPrinterHealth(device.printerHealth),
    printerHealthAt: device.printerHealthAt?.toISOString() ?? null,
    printerRefreshRequestedAt: device.printerRefreshRequestedAt?.toISOString() ?? null,
    printingPausedReason: device.printingPausedReason ?? null,
    trayPages: device.trayPages ?? null,
    trayBaselinePages: device.trayBaselinePages ?? null,
    pagesLeft: pagesLeft(
      device.trayPages,
      device.trayBaselinePages,
      usbPagesTotal(device.printerHealth),
    ),
    bannerHorizontalEnabled: device.bannerHorizontalEnabled !== false,
    bannerVerticalEnabled: device.bannerVerticalEnabled !== false,
    ...printLimitsFromDevice(device),
  };
}

export class DevicesService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {}

  async list() {
    const devices = await this.db.device.findMany({
      include: { site: true },
      orderBy: { createdAt: 'desc' },
    });
    return { items: devices.map(mapDevice) };
  }

  async nearby(query: NearbyDevicesQuery) {
    const devices = await this.db.device.findMany({
      where: {
        status: DeviceStatus.active,
        printingPausedReason: null,
        latitude: { not: null },
        longitude: { not: null },
      },
      include: { site: true },
    });

    const items = devices
      .filter(
        (device): device is typeof device & { latitude: number; longitude: number } =>
          device.latitude != null && device.longitude != null,
      )
      .map((device) => {
        const distanceKm = roundDistanceKm(
          haversineKm(query.lat, query.lng, device.latitude, device.longitude),
        );
        const limits = printLimitsFromDevice(device);
        return {
          id: device.id,
          name: device.name,
          siteName: device.site.name,
          address: device.address,
          latitude: device.latitude,
          longitude: device.longitude,
          distanceKm,
          lastHeartbeatAt: device.lastHeartbeatAt?.toISOString() ?? null,
          ...limits,
          freeDisabledNow: isWithinLocalTimeWindow(
            new Date(),
            limits.freeDisabledFromLocal,
            limits.freeDisabledToLocal,
          ),
        };
      })
      .sort((a, b) => a.distanceKm - b.distanceKm)
      .slice(0, query.limit);

    return { items };
  }

  async register(input: RegisterDeviceInput, adminId: string, correlationId?: string) {
    let tenantId = input.tenantId;
    if (!tenantId) {
      const tenant = await this.db.tenant.findUnique({ where: { code: 'default' } });
      if (!tenant) {
        throw new AppError('tenant_missing', 'Default tenant not found; run seed', 500);
      }
      tenantId = tenant.id;
    }

    let site = await this.db.site.findFirst({
      where: { tenantId, name: input.siteName },
    });
    if (!site) {
      site = await this.db.site.create({
        data: { tenantId, name: input.siteName },
      });
    }

    const deviceKey = `dk_${randomBytes(12).toString('hex')}`;
    const deviceSecret = `ds_${randomBytes(24).toString('hex')}`;
    const deviceSecretHash = await bcrypt.hash(deviceSecret, 10);
    const address = input.address?.trim() ? input.address.trim() : null;

    const device = await this.db.device.create({
      data: {
        tenantId,
        siteId: site.id,
        name: input.name,
        deviceKey,
        deviceSecretHash,
        status: DeviceStatus.provisioning,
        latitude: input.latitude,
        longitude: input.longitude,
        address,
      },
      include: { site: true },
    });

    const services = await this.db.platformService.findMany({ where: { isActive: true } });
    if (services.length > 0) {
      await this.db.serviceEnablement.createMany({
        data: services.map((service) => ({
          tenantId,
          deviceId: device.id,
          serviceId: service.id,
          enabled: true,
        })),
      });
    }

    await this.audit.record({
      action: 'device.registered',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'device',
      resourceId: device.id,
      correlationId,
      metadata: { name: device.name },
    });

    return {
      ...mapDevice(device),
      deviceKey,
      deviceSecret,
    };
  }

  async setStatus(
    deviceId: string,
    status: 'active' | 'inactive',
    adminId: string,
    correlationId?: string,
  ) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      include: { site: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const nextStatus =
      status === 'inactive' ? DeviceStatus.inactive : DeviceStatus.active;

    const updated = await this.db.device.update({
      where: { id: deviceId },
      data: { status: nextStatus },
      include: { site: true },
    });

    await this.audit.record({
      action: nextStatus === DeviceStatus.inactive ? 'device.deactivated' : 'device.activated',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'device',
      resourceId: deviceId,
      correlationId,
      metadata: { status: nextStatus },
    });

    return mapDevice(updated);
  }

  async setSurveillance(
    deviceId: string,
    enabled: boolean,
    adminId: string,
    correlationId?: string,
  ) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      include: { site: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const updated = await this.db.device.update({
      where: { id: deviceId },
      data: { surveillanceEnabled: enabled },
      include: { site: true },
    });

    await this.audit.record({
      action: enabled ? 'device.surveillance_started' : 'device.surveillance_stopped',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'device',
      resourceId: deviceId,
      correlationId,
      metadata: { surveillanceEnabled: enabled },
    });

    return mapDevice(updated);
  }

  async setPrintLimits(
    deviceId: string,
    input: SetDevicePrintLimitsInput,
    adminId: string,
    correlationId?: string,
  ) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      include: { site: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const updated = await this.db.device.update({
      where: { id: deviceId },
      data: {
        maxPagesPerSession: input.maxPagesPerSession,
        freePagesPerSession: input.freePagesPerSession,
        extraPageChargeRupees: input.extraPageChargeRupees,
        freeColorPagesPerSession: input.freeColorPagesPerSession,
        extraColorPageChargeRupees: input.extraColorPageChargeRupees,
        ...(input.freeDisabledFromLocal !== undefined
          ? { freeDisabledFromLocal: input.freeDisabledFromLocal }
          : {}),
        ...(input.freeDisabledToLocal !== undefined
          ? { freeDisabledToLocal: input.freeDisabledToLocal }
          : {}),
        ...(input.bannerHorizontalEnabled !== undefined
          ? { bannerHorizontalEnabled: input.bannerHorizontalEnabled }
          : {}),
        ...(input.bannerVerticalEnabled !== undefined
          ? { bannerVerticalEnabled: input.bannerVerticalEnabled }
          : {}),
      },
      include: { site: true },
    });

    await this.audit.record({
      action: 'device.print_limits_updated',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'device',
      resourceId: deviceId,
      correlationId,
      metadata: { ...input },
    });

    return mapDevice(updated);
  }

  async setPrinterTray(
    deviceId: string,
    input: SetPrinterTrayInput,
    adminId: string,
    correlationId?: string,
  ) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      include: { site: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }
    const usbTotal = usbPagesTotal(device.printerHealth);
    if (usbTotal == null) {
      throw new AppError(
        'printer_page_total_unavailable',
        'The printer page total is not available yet.',
        409,
      );
    }
    const next = applyTrayLoad({
      mode: input.mode,
      pages: input.pages,
      trayPages: device.trayPages,
      trayBaselinePages: device.trayBaselinePages,
      usbTotal,
    });
    const updated = await this.db.device.update({
      where: { id: deviceId },
      data: next,
      include: { site: true },
    });
    await this.audit.record({
      action: 'device.printer_tray_updated',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'device',
      resourceId: deviceId,
      correlationId,
      metadata: {
        mode: input.mode,
        pages: input.pages,
        trayPages: next.trayPages,
        trayBaselinePages: next.trayBaselinePages,
      },
    });
    return mapDevice(updated);
  }

  async requestPrinterRefresh(deviceId: string) {
    const device = await this.db.device.findUnique({ where: { id: deviceId } });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }
    const requestedAt = new Date();
    await this.db.device.update({
      where: { id: deviceId },
      data: { printerRefreshRequestedAt: requestedAt },
    });
    return { requestedAt: requestedAt.toISOString() };
  }

  async getPrinterRefresh(deviceId: string, principalDeviceId: string) {
    if (deviceId !== principalDeviceId) {
      throw new AppError('forbidden', 'Device can only read its own refresh request', 403);
    }
    const device = await this.db.device.findUnique({ where: { id: deviceId } });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }
    if (device.status === DeviceStatus.inactive) {
      throw new AppError('device_inactive', 'This kiosk has been stopped', 403);
    }
    return { requestedAt: device.printerRefreshRequestedAt?.toISOString() ?? null };
  }

  async heartbeat(
    deviceId: string,
    principalDeviceId: string,
    body: DeviceHeartbeatBody = {},
  ) {
    if (deviceId !== principalDeviceId) {
      throw new AppError('forbidden', 'Device can only heartbeat itself', 403);
    }

    const device = await this.db.device.findUnique({ where: { id: deviceId } });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }
    if (device.status === DeviceStatus.inactive) {
      throw new AppError('device_inactive', 'This kiosk has been stopped', 403);
    }

    const now = new Date();
    const latchPaperOut =
      !device.printingPausedReason && printerReportsPaperOut(body.printer);
    await this.db.device.update({
      where: { id: deviceId },
      data: {
        lastHeartbeatAt: now,
        ...(latchPaperOut ? { printingPausedReason: PRINTING_PAUSED_PAPER_OUT } : {}),
        ...(body.surveillance
          ? {
              surveillanceHealth: body.surveillance,
              surveillanceHealthAt: now,
            }
          : {}),
        ...(body.printer
          ? {
              printerHealth: body.printer,
              printerHealthAt: now,
            }
          : {}),
        ...(body.printer &&
        ackMatchesRefresh(device.printerRefreshRequestedAt, body.printerRefreshAck)
          ? { printerRefreshRequestedAt: null }
          : {}),
        ...(device.status === DeviceStatus.provisioning
          ? { status: DeviceStatus.active }
          : {}),
      },
    });

    return {
      surveillanceEnabled: device.surveillanceEnabled,
      printingPausedReason: latchPaperOut
        ? PRINTING_PAUSED_PAPER_OUT
        : (device.printingPausedReason ?? null),
    };
  }

  async enablePrinting(deviceId: string, adminId: string, correlationId?: string) {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      include: { site: true },
    });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }
    if (printerReportsPaperOut(device.printerHealth)) {
      throw new AppError(
        'printer_still_out_of_paper',
        'The printer still reports it is out of paper',
        409,
      );
    }
    if (!device.printingPausedReason) {
      return mapDevice(device);
    }
    const updated = await this.db.device.update({
      where: { id: deviceId },
      data: { printingPausedReason: null },
      include: { site: true },
    });
    await this.audit.record({
      action: 'device.printing_enabled',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'device',
      resourceId: deviceId,
      correlationId,
    });
    return mapDevice(updated);
  }
}
