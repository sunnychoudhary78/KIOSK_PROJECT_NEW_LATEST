import multer from 'multer';
import rateLimit from 'express-rate-limit';
import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { requireDevice } from '../../shared/device-guard.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { OtpPrintService } from '../otp_print/otp_print.service.js';
import { PaymentsService } from '../payments/payments.service.js';
import { RazorpayClient } from '../payments/razorpay.client.js';
import { PrintingService } from '../printing/printing.service.js';
import { ServicesCatalogService } from '../services/services.service.js';
import { createPlacesClient } from '../../infrastructure/external/places.client.js';
import {
  createKundaliBodySchema,
  createMatchBodySchema,
  createReadingFieldsSchema,
  createTodayBodySchema,
  placeIdParamSchema,
  placesQuerySchema,
  printKundaliBodySchema,
  printMatchBodySchema,
  printReadingBodySchema,
  printTodayBodySchema,
  verifyAstrologyPrintPaymentSchema,
  type UploadedPalm,
} from './astrology.schemas.js';
import { AstrologyService } from './astrology.service.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { files: 1, fileSize: 5 * 1024 * 1024 },
});

export function registerAstrologyModule(router: Router, deps: AppDeps): void {
  const services = new ServicesCatalogService(deps.db, deps.auditService);
  const printing = new PrintingService(deps.db, deps.auditService);
  const razorpay = new RazorpayClient(deps.config);
  const otpPrint = new OtpPrintService(
    deps.db,
    deps.config,
    deps.auditService,
    printing,
    services,
    deps.sms,
  );
  const payments = new PaymentsService(
    deps.db,
    deps.config,
    razorpay,
    otpPrint,
    deps.auditService,
  );
  const service = new AstrologyService(
    deps.db,
    deps.vedastro,
    deps.astrologyLlm,
    deps.auditService,
    services,
    deps.logger,
    deps.config,
    razorpay,
    payments,
  );
  const places = createPlacesClient({
    apiKey: process.env.SKP_GOOGLE_PLACES_API_KEY,
    logger: deps.logger,
  });
  const publicLimiter = rateLimit({
    windowMs: 60_000,
    max: 40,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => req.ip ?? 'unknown',
    message: {
      code: 'rate_limited',
      message: 'Too many requests',
      correlationId: 'rate_limited',
    },
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

  router.post(
    '/astrology/kundali/print',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const parsed = printKundaliBodySchema.safeParse(req.body);
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const job = await service.printKundali(
          req.principal.deviceId,
          parsed.data,
          req.correlationId,
        );
        res.status(200).json(job);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/astrology/match/print',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const parsed = printMatchBodySchema.safeParse(req.body);
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const job = await service.printMatch(
          req.principal.deviceId,
          parsed.data,
          req.correlationId,
        );
        res.status(200).json(job);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/astrology/readings/print',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const parsed = printReadingBodySchema.safeParse(req.body);
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const job = await service.printReading(
          req.principal.deviceId,
          parsed.data,
          req.correlationId,
        );
        res.status(200).json(job);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/astrology/today/print',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const parsed = printTodayBodySchema.safeParse(req.body);
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const job = await service.printToday(
          req.principal.deviceId,
          parsed.data,
          req.correlationId,
        );
        res.status(200).json(job);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/astrology/print-jobs/:jobId/payment',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const jobId = requireParam(req.params.jobId, 'jobId');
        res.json(await service.getPrintJobPayment(req.principal.deviceId, jobId));
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/astrology/print-checkout/:token',
    publicLimiter,
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const token = requireParam(req.params.token, 'token');
        res.json(await service.getPrintCheckout(token));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/astrology/print-checkout/:token/razorpay/order',
    publicLimiter,
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const token = requireParam(req.params.token, 'token');
        res.status(201).json(await service.createPrintCheckoutOrder(token, req.correlationId));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/astrology/print-checkout/:token/razorpay/verify',
    publicLimiter,
    validateBody(verifyAstrologyPrintPaymentSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const token = requireParam(req.params.token, 'token');
        res.json(
          await service.verifyPrintCheckoutPayment(token, req.body, req.correlationId),
        );
      } catch (error) {
        next(error);
      }
    },
  );
}

export { AstrologyService } from './astrology.service.js';
