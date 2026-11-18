import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { screenShareAckBodySchema } from './screen_share.schemas.js';
import { ScreenShareService } from './screen_share.service.js';

export {
  SCREEN_SHARE_EXPIRE_BATCH_SIZE,
  SCREEN_SHARE_PENDING_TTL_MS,
} from './screen_share.constants.js';
export { ScreenShareService } from './screen_share.service.js';

export function registerScreenShareModule(router: Router, deps: AppDeps): void {
  const service = new ScreenShareService(deps.db, deps.auditService, deps.config);

  router.post(
    '/devices/:deviceId/screen-share/start',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.start(
          requireParam(req.params.deviceId, 'deviceId'),
          req.principal.id,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/devices/:deviceId/screen-share/end',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.end(
          requireParam(req.params.deviceId, 'deviceId'),
          req.principal.id,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/devices/:deviceId/screen-share',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const result = await service.getCurrent(requireParam(req.params.deviceId, 'deviceId'));
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/devices/:deviceId/screen-share/pending',
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
    '/devices/:deviceId/screen-share/ack',
    ...requireDevice(deps),
    validateBody(screenShareAckBodySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.ack(
          requireParam(req.params.deviceId, 'deviceId'),
          req.principal.deviceId,
          req.body,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}
