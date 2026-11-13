import type { NextFunction, Request, Response, Router } from 'express';
import { UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { createKioskReleaseSchema } from './kiosk_releases.schemas.js';
import { KioskReleasesService } from './kiosk_releases.service.js';

function requireUpdateKey(expectedKey: string) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!expectedKey) {
      next(
        new AppError('update_key_not_configured', 'Kiosk update key is not configured', 503),
      );
      return;
    }
    const provided = req.header('x-update-key');
    if (!provided || provided !== expectedKey) {
      next(new AppError('unauthorized', 'Invalid or missing update key', 401));
      return;
    }
    next();
  };
}

export function registerKioskReleasesModule(router: Router, deps: AppDeps): void {
  const service = new KioskReleasesService(deps.db, deps.objectStorage, deps.auditService);

  router.get(
    '/kiosk-updates/current',
    requireUpdateKey(deps.config.kioskUpdateKey),
    async (_req: Request, res: Response, next: NextFunction) => {
      try {
        const result = await service.getCurrentUpdate(deps.config.kioskUpdateKey);
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/kiosk-releases',
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

  router.post(
    '/kiosk-releases',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    validateBody(createKioskReleaseSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.createUpload(
          req.body,
          req.principal.id,
          req.correlationId,
        );
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/kiosk-releases/:releaseId/complete',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.complete(
          requireParam(req.params.releaseId, 'releaseId'),
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
    '/kiosk-releases/:releaseId/activate',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.activate(
          requireParam(req.params.releaseId, 'releaseId'),
          req.principal.id,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.delete(
    '/kiosk-releases/:releaseId',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.remove(
          requireParam(req.params.releaseId, 'releaseId'),
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
