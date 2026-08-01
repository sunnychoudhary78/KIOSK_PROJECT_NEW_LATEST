import { randomBytes } from 'node:crypto';
import bcrypt from 'bcryptjs';
import { DeviceStatus } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import type { RegisterDeviceInput } from './devices.schemas.js';

function mapDevice(device: {
  id: string;
  name: string;
  deviceKey: string;
  status: DeviceStatus;
  lastHeartbeatAt: Date | null;
  site: { name: string };
}) {
  return {
    id: device.id,
    name: device.name,
    deviceKey: device.deviceKey,
    status: device.status,
    siteName: device.site.name,
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

    const device = await this.db.device.create({
      data: {
        tenantId,
        siteId: site.id,
        name: input.name,
        deviceKey,
        deviceSecretHash,
        status: DeviceStatus.provisioning,
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
