import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { validateBody, validateQuery } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { DevicesService } from './devices.service.js';
import { nearbyDevicesQuerySchema, registerDeviceSchema } from './devices.schemas.js';
import type { NearbyDevicesQuery } from './devices.schemas.js';

export function registerDevicesModule(router: Router, deps: AppDeps): void {
  const service = new DevicesService(deps.db, deps.auditService);

  router.get(
    '/devices',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (_req: Request, res: Response, next: NextFunction) => {
      try {
        res.json(await service.list());
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/devices/nearby',
    authRequired(deps.config, ['citizen']),
    validateQuery(nearbyDevicesQuerySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const query = req.query as unknown as NearbyDevicesQuery;
        res.json(await service.nearby(query));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/devices',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    validateBody(registerDeviceSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.register(req.body, req.principal.id, req.correlationId);
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/devices/:deviceId/heartbeat',
    authRequired(deps.config, ['device']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        await service.heartbeat(
          requireParam(req.params.deviceId, 'deviceId'),
          req.principal.deviceId,
          req.correlationId,
        );
        res.status(204).send();
      } catch (error) {
        next(error);
      }
    },
  );
}

export { DevicesService } from './devices.service.js';
