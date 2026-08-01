import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import type { ServiceEnablementInput } from './services.schemas.js';

export class ServicesCatalogService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {}

  async listForDevice(deviceId?: string) {
    const services = await this.db.platformService.findMany({
      where: { isActive: true },
      orderBy: { code: 'asc' },
    });

    if (!deviceId) {
      return {
        items: services.map((s) => ({
          code: s.code,
          name: s.name,
          description: s.description ?? undefined,
          enabled: true,
        })),
      };
    }

    const enablements = await this.db.serviceEnablement.findMany({
      where: { deviceId },
    });
    const byServiceId = new Map(enablements.map((e) => [e.serviceId, e.enabled]));

    return {
      items: services.map((s) => ({
        code: s.code,
        name: s.name,
        description: s.description ?? undefined,
        enabled: byServiceId.get(s.id) ?? false,
      })),
    };
  }

  async setEnablement(
    serviceCode: string,
    input: ServiceEnablementInput,
    adminId: string,
    correlationId?: string,
  ) {
    const service = await this.db.platformService.findUnique({ where: { code: serviceCode } });
    if (!service) {
      throw new AppError('not_found', `Unknown service: ${serviceCode}`, 404);
    }

    const device = await this.db.device.findUnique({ where: { id: input.deviceId } });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const enablement = await this.db.serviceEnablement.upsert({
      where: {
        deviceId_serviceId: {
          deviceId: input.deviceId,
          serviceId: service.id,
        },
      },
      update: { enabled: input.enabled },
      create: {
        tenantId: device.tenantId,
        deviceId: input.deviceId,
        serviceId: service.id,
        enabled: input.enabled,
      },
    });

    await this.audit.record({
      action: 'service.enablement_updated',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'platform_service',
      resourceId: service.id,
      correlationId,
      metadata: { serviceCode, deviceId: input.deviceId, enabled: input.enabled },
    });

    return {
      code: service.code,
      deviceId: enablement.deviceId,
      enabled: enablement.enabled,
    };
  }

  async assertEnabled(deviceId: string, serviceCode: string): Promise<void> {
    const service = await this.db.platformService.findUnique({ where: { code: serviceCode } });
    if (!service || !service.isActive) {
      throw new AppError('service_unavailable', `Service ${serviceCode} is not available`, 403);
    }

    const enablement = await this.db.serviceEnablement.findUnique({
      where: {
        deviceId_serviceId: { deviceId, serviceId: service.id },
      },
    });

    if (!enablement?.enabled) {
      throw new AppError('service_disabled', `Service ${serviceCode} is disabled for this device`, 403);
    }
  }
}
