import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import {
  createSurveillanceCommandBodySchema,
  surveillanceCommandAckBodySchema,
} from './surveillance_commands.schemas.js';
import { SurveillanceCommandsService } from './surveillance_commands.service.js';

export {
  SURVEILLANCE_COMMAND_EXPIRE_BATCH_SIZE,
  SURVEILLANCE_COMMAND_PENDING_TTL_MS,
} from './surveillance_commands.constants.js';
export { SurveillanceCommandsService } from './surveillance_commands.service.js';

export function registerSurveillanceCommandsModule(router: Router, deps: AppDeps): void {
  const service = new SurveillanceCommandsService(deps.db, deps.auditService);

  router.post(
    '/devices/:deviceId/surveillance/commands',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    validateBody(createSurveillanceCommandBodySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.create(
          requireParam(req.params.deviceId, 'deviceId'),
          req.principal.id,
          req.body,
          req.correlationId,
        );
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/devices/:deviceId/surveillance/commands/latest',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const result = await service.getLatest(requireParam(req.params.deviceId, 'deviceId'));
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/devices/:deviceId/surveillance/commands/pending',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.getPendingForDevice(
          requireParam(req.params.deviceId, 'deviceId'),
          req.principal.deviceId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/devices/:deviceId/surveillance/commands/:commandId/ack',
    ...requireDevice(deps),
    validateBody(surveillanceCommandAckBodySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.ack(
          requireParam(req.params.deviceId, 'deviceId'),
          req.principal.deviceId,
          requireParam(req.params.commandId, 'commandId'),
          req.body,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}
