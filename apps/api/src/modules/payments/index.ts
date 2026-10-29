import express, { type Express, type NextFunction, type Request, type Response, type Router } from 'express';
import { SupportResolution, UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { validateBody, validateQuery } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { PrintingService } from '../printing/printing.service.js';
import { ServicesCatalogService } from '../services/services.service.js';
import { OtpPrintService } from '../otp_print/otp_print.service.js';
import { PaymentsService } from './payments.service.js';
import { RazorpayClient } from './razorpay.client.js';
import {
  createRazorpayOrderSchema,
  listSupportQueriesQuerySchema,
  openSupportQuerySchema,
  resolveSupportQuerySchema,
  supportQueryChallengeQuerySchema,
  verifyRazorpayPaymentSchema,
} from './payments.schemas.js';

function createPaymentsService(deps: AppDeps): PaymentsService {
  const printing = new PrintingService(deps.db, deps.auditService);
  const services = new ServicesCatalogService(deps.db, deps.auditService);
  const otpPrint = new OtpPrintService(
    deps.db,
    deps.config,
    deps.auditService,
    printing,
    services,
    deps.sms,
  );
  return new PaymentsService(
    deps.db,
    deps.config,
    new RazorpayClient(deps.config),
    otpPrint,
    deps.auditService,
  );
}

export function registerRazorpayWebhook(app: Express, deps: AppDeps): void {
  const service = createPaymentsService(deps);
  app.post(
    '/v1/payments/razorpay/webhook',
    express.raw({ type: 'application/json' }),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const rawBody = Buffer.isBuffer(req.body) ? req.body : Buffer.from(String(req.body ?? ''));
        const signature = req.header('x-razorpay-signature');
        const result = await service.handleWebhook(rawBody, signature, req.correlationId);
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );
}

export function registerPaymentsModule(router: Router, deps: AppDeps): void {
  const service = createPaymentsService(deps);

  router.post(
    '/payments/razorpay/order',
    authRequired(deps.config, ['citizen']),
    validateBody(createRazorpayOrderSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.createCheckoutOrder(
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

  router.post(
    '/payments/razorpay/verify',
    authRequired(deps.config, ['citizen']),
    validateBody(verifyRazorpayPaymentSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.verifyCheckoutPayment(
          req.principal.id,
          req.body,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/payments/support-query',
    authRequired(deps.config, ['citizen']),
    validateQuery(supportQueryChallengeQuerySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.getSupportQuery(
          req.principal.id,
          String(req.query.challengeId),
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/payments/support-query',
    authRequired(deps.config, ['citizen']),
    validateBody(openSupportQuerySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.openSupportQuery(
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
    '/support-queries',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    validateQuery(listSupportQueriesQuerySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const status = req.query.status === 'open' || req.query.status === 'resolved'
          ? req.query.status
          : undefined;
        const source = req.query.source === 'payment' || req.query.source === 'print'
          ? req.query.source
          : undefined;
        res.json(await service.listSupportQueries({ status, source }));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/support-queries/:queryId/resolve',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    validateBody(resolveSupportQuerySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.resolveSupportQuery(
          requireParam(req.params.queryId, 'queryId'),
          req.principal.id,
          req.body.resolution as SupportResolution,
          req.correlationId,
        );
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/support-queries/:queryId/resend-otp',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.resendSupportOtp(
          requireParam(req.params.queryId, 'queryId'),
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
