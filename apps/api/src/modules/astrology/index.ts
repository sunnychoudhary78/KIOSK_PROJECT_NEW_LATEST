import multer from 'multer';
import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { requireDevice } from '../../shared/device-guard.js';
import { AppError } from '../../shared/errors.js';
import { ServicesCatalogService } from '../services/services.service.js';
import { createPlacesClient } from '../../infrastructure/external/places.client.js';
import {
  createKundaliBodySchema,
  createMatchBodySchema,
  createReadingFieldsSchema,
  createTodayBodySchema,
  placeIdParamSchema,
  placesQuerySchema,
  type UploadedPalm,
} from './astrology.schemas.js';
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
  const places = createPlacesClient({
    apiKey: process.env.SKP_GOOGLE_PLACES_API_KEY,
    logger: deps.logger,
  });

  router.get(
    '/astrology/places',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const parsed = placesQuerySchema.safeParse(req.query);
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const suggestions = await places.autocomplete(parsed.data.q);
        res.status(200).json({ suggestions });
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/astrology/places/:id',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const parsed = placeIdParamSchema.safeParse({
          id: decodeURIComponent(String(req.params.id ?? '')),
        });
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const place = await places.resolve(parsed.data.id);
        res.status(200).json(place);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/astrology/readings',
    ...requireDevice(deps),
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

  router.post(
    '/astrology/kundali',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const parsed = createKundaliBodySchema.safeParse(req.body);
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const result = await service.createKundali(
          req.principal.deviceId,
          parsed.data,
          req.correlationId,
        );
        res.status(200).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/astrology/match',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const parsed = createMatchBodySchema.safeParse(req.body);
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const result = await service.createMatch(
          req.principal.deviceId,
          parsed.data,
          req.correlationId,
        );
        res.status(200).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/astrology/today',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const parsed = createTodayBodySchema.safeParse(req.body);
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const result = await service.createToday(
          req.principal.deviceId,
          parsed.data,
          req.correlationId,
        );
        res.status(200).json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

export { AstrologyService } from './astrology.service.js';
