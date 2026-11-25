import type { NextFunction, Request, Response, Router } from 'express';
import multer from 'multer';
import type { AppDeps } from '../../types/deps.js';
import { authRequired } from '../../shared/auth.js';
import { assertActiveDevice } from '../../shared/device-guard.js';
import { validateBody, validateQuery } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { ServicesCatalogService } from '../services/services.service.js';
import {
  createLocalServiceCategorySchema,
  createLocalServiceContactSchema,
  nearbyLocalServicesQuerySchema,
  setLocalServiceCategoryStatusSchema,
  updateLocalServiceContactSchema,
} from './local_services.schemas.js';
import type { NearbyLocalServicesQuery } from './local_services.schemas.js';
import { LocalServicesService } from './local_services.service.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 },
});

export function registerLocalServicesModule(router: Router, deps: AppDeps): void {
  const services = new ServicesCatalogService(deps.db, deps.auditService);
  const service = new LocalServicesService(deps.db, deps.auditService, services);

  router.get(
    '/local-services',
    authRequired(deps.config, ['admin', 'device', 'citizen']),
    assertActiveDevice(deps.db),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const deviceId =
          req.principal?.type === 'device' ? req.principal.deviceId : undefined;
        const includeInactive = req.principal?.type === 'admin';
        res.json(await service.list(deviceId, { includeInactive }));
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/local-services/nearby',
    authRequired(deps.config, ['citizen']),
    validateQuery(nearbyLocalServicesQuerySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const query = req.query as unknown as NearbyLocalServicesQuery;
        res.json(await service.nearby(query));
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/local-services/contacts/:contactId/photo',
    authRequired(deps.config, ['admin', 'device', 'citizen']),
    assertActiveDevice(deps.db),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const photo = await service.readContactPhoto(
          requireParam(req.params.contactId, 'contactId'),
        );
        res.setHeader('Content-Type', photo.contentType);
        res.setHeader('Cache-Control', 'private, max-age=300');
        res.send(photo.bytes);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/local-services',
    authRequired(deps.config, ['admin']),
    validateBody(createLocalServiceCategorySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.createCategory(req.body, req.principal.id, req.correlationId);
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.patch(
    '/local-services/:id/status',
    authRequired(deps.config, ['admin']),
    validateBody(setLocalServiceCategoryStatusSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.setCategoryStatus(
          requireParam(req.params.id, 'id'),
          req.body.isActive === true,
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
    '/local-services/:id',
    authRequired(deps.config, ['admin']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        await service.removeCategory(
          requireParam(req.params.id, 'id'),
          req.principal.id,
          req.correlationId,
        );
        res.status(204).send();
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/local-services/:id/contacts',
    authRequired(deps.config, ['admin']),
    validateBody(createLocalServiceContactSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.createContact(
          requireParam(req.params.id, 'id'),
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

  router.patch(
    '/local-services/:id/contacts/:contactId',
    authRequired(deps.config, ['admin']),
    validateBody(updateLocalServiceContactSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.updateContact(
          requireParam(req.params.id, 'id'),
          requireParam(req.params.contactId, 'contactId'),
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

  router.post(
    '/local-services/:id/contacts/:contactId/photo',
    authRequired(deps.config, ['admin']),
    upload.single('photo'),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const file = req.file;
        if (!file) {
          throw new AppError('invalid_file', 'Photo file is required', 400);
        }
        const result = await service.setContactPhoto(
          requireParam(req.params.id, 'id'),
          requireParam(req.params.contactId, 'contactId'),
          {
            buffer: file.buffer,
            mimetype: file.mimetype,
            originalname: file.originalname,
          },
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
    '/local-services/:id/contacts/:contactId',
    authRequired(deps.config, ['admin']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        await service.removeContact(
          requireParam(req.params.id, 'id'),
          requireParam(req.params.contactId, 'contactId'),
          req.principal.id,
          req.correlationId,
        );
        res.status(204).send();
      } catch (error) {
        next(error);
      }
    },
  );
}
