import { readFile } from 'node:fs/promises';
import multer from 'multer';
import rateLimit from 'express-rate-limit';
import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { PrintingService } from '../printing/printing.service.js';
import { ServicesCatalogService } from '../services/services.service.js';
import { OtpPrintService } from '../otp_print/otp_print.service.js';
import { PaymentsService } from '../payments/payments.service.js';
import { RazorpayClient } from '../payments/razorpay.client.js';
import { parsePrintColorMode, type UploadedPdf } from '../otp_print/otp_print.schemas.js';
import { QuickPrintService } from './quick_print.service.js';
import { verifyQuickPrintPaymentSchema } from './quick_print.schemas.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { files: 20, fileSize: 50 * 1024 * 1024 },
});

function createService(deps: AppDeps): QuickPrintService {
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
  const razorpay = new RazorpayClient(deps.config);
  const payments = new PaymentsService(deps.db, deps.config, razorpay, otpPrint, deps.auditService);
  return new QuickPrintService(
    deps.db,
    deps.config,
    deps.auditService,
    printing,
    services,
    razorpay,
    payments,
  );
}

export function registerQuickPrintModule(router: Router, deps: AppDeps): void {
  const service = createService(deps);
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

  router.post(
    '/quick-print/sessions',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.createSession(req.principal.deviceId, req.correlationId);
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/quick-print/sessions/:sessionId',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const sessionId = requireParam(req.params.sessionId, 'sessionId');
        res.json(await service.getForDevice(req.principal.deviceId, sessionId));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/quick-print/sessions/:sessionId/claim',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const sessionId = requireParam(req.params.sessionId, 'sessionId');
        res.json(await service.claim(req.principal.deviceId, sessionId, req.correlationId));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/quick-print/sessions/:sessionId/cancel',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const sessionId = requireParam(req.params.sessionId, 'sessionId');
        res.json(await service.cancel(req.principal.deviceId, sessionId, req.correlationId));
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/quick-print/sessions/:sessionId/documents/:documentId/content',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const sessionId = requireParam(req.params.sessionId, 'sessionId');
        const documentId = requireParam(req.params.documentId, 'documentId');
        const doc = await service.getDocumentContent(req.principal.deviceId, sessionId, documentId);
        const bytes = await readFile(doc.storagePath);
        res.setHeader('Content-Type', doc.contentType || 'application/pdf');
        res.setHeader(
          'Content-Disposition',
          `inline; filename="${doc.fileName.replace(/"/g, '')}"`,
        );
        res.send(bytes);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/quick-print/public/sessions/:token',
    publicLimiter,
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const token = requireParam(req.params.token, 'token');
        res.json(await service.getByToken(token));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/quick-print/public/sessions/:token/documents',
    publicLimiter,
    upload.array('files', 20),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const token = requireParam(req.params.token, 'token');
        const files = (req.files as Express.Multer.File[] | undefined) ?? [];
        const uploaded: UploadedPdf[] = files.map((file) => ({
          originalname: file.originalname,
          mimetype: file.mimetype,
          size: file.size,
          buffer: file.buffer,
        }));
        const printColorMode = parsePrintColorMode(req.body?.printColorMode);
        res.status(201).json(
          await service.uploadDocuments(token, uploaded, printColorMode, req.correlationId),
        );
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/quick-print/public/sessions/:token/razorpay/order',
    publicLimiter,
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const token = requireParam(req.params.token, 'token');
        res.status(201).json(await service.createCheckoutOrder(token, req.correlationId));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/quick-print/public/sessions/:token/razorpay/verify',
    publicLimiter,
    validateBody(verifyQuickPrintPaymentSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        const token = requireParam(req.params.token, 'token');
        res.json(await service.verifyCheckoutPayment(token, req.body, req.correlationId));
      } catch (error) {
        next(error);
      }
    },
  );
}

export { QuickPrintService } from './quick_print.service.js';
