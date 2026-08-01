import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { ServicesCatalogService } from './services.service.js';
import { serviceEnablementSchema } from './services.schemas.js';

export function registerServicesModule(router: Router, deps: AppDeps): void {
  const service = new ServicesCatalogService(deps.db, deps.auditService);

  router.get(
    '/services',
    authRequired(deps.config, ['admin', 'device', 'citizen']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const deviceId =
          typeof req.query.deviceId === 'string'
            ? req.query.deviceId
            : req.principal?.type === 'device'
              ? req.principal.deviceId
              : undefined;
        res.json(await service.listForDevice(deviceId));
      } catch (error) {
        next(error);
      }
    },
  );

  router.put(
    '/services/:serviceCode/enablement',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    validateBody(serviceEnablementSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.setEnablement(
          requireParam(req.params.serviceCode, 'serviceCode'),
          req.body,
          req.principal.id,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

export { ServicesCatalogService } from './services.service.js';
