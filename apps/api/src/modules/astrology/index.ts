import multer from 'multer';
import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { authRequired } from '../../shared/auth.js';
import { AppError } from '../../shared/errors.js';
import { ServicesCatalogService } from '../services/services.service.js';
import { createReadingFieldsSchema, type UploadedPalm } from './astrology.schemas.js';
import { AstrologyService } from './astrology.service.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { files: 1, fileSize: 5 * 1024 * 1024 },
});

export function registerAstrologyModule(router: Router, deps: AppDeps): void {
  const services = new ServicesCatalogService(deps.db, deps.auditService);
  const service = new AstrologyService(
    deps.db,
    deps.vedastro,
    deps.astrologyLlm,
    deps.auditService,
    services,
    deps.logger,
  );

  router.post(
    '/astrology/readings',
    authRequired(deps.config, ['device']),
    upload.single('palm'),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const file = req.file;
        if (!file) {
          throw new AppError('validation_error', 'Palm image is required', 400);
        }
        const parsed = createReadingFieldsSchema.safeParse(req.body);
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const palm: UploadedPalm = {
          originalname: file.originalname,
          mimetype: file.mimetype,
          size: file.size,
          buffer: file.buffer,
        };
        const result = await service.createReading(
          req.principal.deviceId,
          parsed.data,
          palm,
          req.correlationId,
        );
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

export { AstrologyService } from './astrology.service.js';
