import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { RazorpayClient } from '../payments/razorpay.client.js';
import {
  wellBeingOtpRequestSchema,
  wellBeingOtpVerifySchema,
  wellBeingPrintBodySchema,
} from './well_being.schemas.js';
import { WellBeingService } from './well_being.service.js';

function createWellBeingService(deps: AppDeps): WellBeingService {
  const razorpay = new RazorpayClient(deps.config);
  return new WellBeingService(
    deps.db,
    deps.auditService,
    deps.config,
    razorpay,
    deps.sms,
  );
}

export function registerWellBeingModule(router: Router, deps: AppDeps): void {
  const service = createWellBeingService(deps);

  router.get(
    '/well-being/print-options',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        res.json(await service.getPrintOptions(req.principal.deviceId));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/well-being/otp-request',
    ...requireDevice(deps),
    validateBody(wellBeingOtpRequestSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        res.json(
          await service.requestPhoneOtp(
            req.principal.deviceId,
            req.body.phone,
            req.correlationId,
          ),
        );
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/well-being/otp-verify',
    ...requireDevice(deps),
    validateBody(wellBeingOtpVerifySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        res.json(
          await service.verifyPhoneOtp(
            req.principal.deviceId,
            req.body.phone,
            req.body.otp,
            req.body.colorMode,
            req.correlationId,
          ),
        );
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/well-being/print-jobs/:jobId/payment',
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

  router.post(
    '/well-being/print',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const parsed = wellBeingPrintBodySchema.safeParse(req.body);
        if (!parsed.success) {
          throw new AppError(
            'validation_error',
            'Request validation failed',
            400,
            parsed.error.flatten(),
          );
        }
        const job = await service.printReport(
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
}

export { WellBeingService } from './well_being.service.js';
