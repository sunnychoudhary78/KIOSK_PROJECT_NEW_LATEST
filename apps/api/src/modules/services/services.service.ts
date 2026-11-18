import { ServiceOperationalStatus } from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import type {
  ServiceEnablementInput,
  SetServiceOperationalStatusInput,
} from './services.schemas.js';

/** Home “Print Documents” umbrella → print feature codes gated by the same status. */
const PRINT_CHILD_CODES = ['otp_print', 'quick_print', 'digilocker_print'] as const;

function mapServiceItem(service: {
  code: string;
  name: string;
  description: string | null;
  operationalStatus: ServiceOperationalStatus;
  enabled: boolean;
}) {
  return {
    code: service.code,
    name: service.name,
    description: service.description ?? undefined,
    enabled: service.enabled,
    status: service.operationalStatus,
  };
}

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
        items: services.map((s) =>
          mapServiceItem({
            code: s.code,
            name: s.name,
            description: s.description,
            operationalStatus: s.operationalStatus,
            enabled: true,
          }),
        ),
      };
    }

    const enablements = await this.db.serviceEnablement.findMany({
      where: { deviceId },
    });
    const byServiceId = new Map(enablements.map((e) => [e.serviceId, e.enabled]));

    return {
      items: services.map((s) =>
        mapServiceItem({
          code: s.code,
          name: s.name,
          description: s.description,
          operationalStatus: s.operationalStatus,
          enabled: byServiceId.get(s.id) ?? false,
        }),
      ),
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
      status: service.operationalStatus,
    };
  }

  async setOperationalStatus(
    serviceCode: string,
    input: SetServiceOperationalStatusInput,
    adminId: string,
    correlationId?: string,
  ) {
    const service = await this.db.platformService.findUnique({ where: { code: serviceCode } });
    if (!service || !service.isActive) {
      throw new AppError('not_found', `Unknown service: ${serviceCode}`, 404);
    }

    const status = input.status as ServiceOperationalStatus;
    const codesToUpdate =
      serviceCode === 'print' ? ['print', ...PRINT_CHILD_CODES] : [serviceCode];

    await this.db.platformService.updateMany({
      where: { code: { in: codesToUpdate }, isActive: true },
      data: { operationalStatus: status },
    });

    await this.audit.record({
      action: 'service.operational_status_updated',
      principalType: 'admin',
      principalId: adminId,
      resourceType: 'platform_service',
      resourceId: service.id,
      correlationId,
      metadata: { serviceCode, status, cascadedCodes: codesToUpdate },
    });

    const updated = await this.db.platformService.findUnique({ where: { code: serviceCode } });
    return mapServiceItem({
      code: service.code,
      name: service.name,
      description: service.description,
      operationalStatus: updated?.operationalStatus ?? status,
      enabled: true,
    });
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

    const umbrella =
      PRINT_CHILD_CODES.includes(serviceCode as (typeof PRINT_CHILD_CODES)[number])
        ? await this.db.platformService.findUnique({ where: { code: 'print' } })
        : null;
    const effectiveStatus = umbrella?.isActive
      ? umbrella.operationalStatus
      : service.operationalStatus;

    if (effectiveStatus === ServiceOperationalStatus.out_of_service) {
      throw new AppError(
        'service_out_of_service',
        `Service ${serviceCode} is out of service`,
        403,
      );
    }
    if (effectiveStatus === ServiceOperationalStatus.under_maintenance) {
      throw new AppError(
        'service_under_maintenance',
        `Service ${serviceCode} is under maintenance`,
        403,
      );
    }
  }
}
