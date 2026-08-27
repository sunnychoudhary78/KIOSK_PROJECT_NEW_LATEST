import { randomBytes } from 'node:crypto';
import bcrypt from 'bcryptjs';
import { DeviceStatus } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import { haversineKm, roundDistanceKm } from '../../shared/geo.js';
import type { AuditService } from '../audit/audit.service.js';
import type { NearbyDevicesQuery, RegisterDeviceInput } from './devices.schemas.js';

function mapDevice(device: {
  id: string;
  name: string;
  deviceKey: string;
  status: DeviceStatus;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  lastHeartbeatAt: Date | null;
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
        return {
          id: device.id,
          name: device.name,
          siteName: device.site.name,
          address: device.address,
          latitude: device.latitude,
          longitude: device.longitude,
          distanceKm,
          lastHeartbeatAt: device.lastHeartbeatAt?.toISOString() ?? null,
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

  async heartbeat(deviceId: string, principalDeviceId: string, correlationId?: string) {
    if (deviceId !== principalDeviceId) {
      throw new AppError('forbidden', 'Device can only heartbeat itself', 403);
    }

    const device = await this.db.device.findUnique({ where: { id: deviceId } });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    await this.db.device.update({
      where: { id: deviceId },
      data: { lastHeartbeatAt: new Date(), status: DeviceStatus.active },
    });

    await this.audit.record({
      action: 'device.heartbeat',
      principalType: 'device',
      principalId: deviceId,
      resourceType: 'device',
      resourceId: deviceId,
      correlationId,
    });
  }
}
