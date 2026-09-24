import { readFile } from 'node:fs/promises';
import multer from 'multer';
import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { authRequired } from '../../shared/auth.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { PrintingService } from '../printing/printing.service.js';
import { ServicesCatalogService } from '../services/services.service.js';
import { OtpPrintService } from './otp_print.service.js';
import { parsePrintColorMode, redeemOtpSchema, type UploadedPdf } from './otp_print.schemas.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { files: 20, fileSize: 50 * 1024 * 1024 },
});

export function registerOtpPrintModule(router: Router, deps: AppDeps): void {
  const printing = new PrintingService(deps.db, deps.auditService);
  const services = new ServicesCatalogService(deps.db, deps.auditService);
  const service = new OtpPrintService(
    deps.db,
    deps.config,
    deps.auditService,
    printing,
    services,
    deps.sms,
  );

  router.post(
    '/otp-challenges',
    authRequired(deps.config, ['citizen']),
    upload.array('files', 20),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const files = (req.files as Express.Multer.File[] | undefined) ?? [];
        const uploaded: UploadedPdf[] = files.map((f) => ({
          originalname: f.originalname,
          mimetype: f.mimetype,
          size: f.size,
          buffer: f.buffer,
        }));
        const documentLabel =
          typeof req.body?.documentLabel === 'string' ? req.body.documentLabel : undefined;
        const printColorMode = parsePrintColorMode(req.body?.printColorMode);
        const result = await service.createChallenge(
          req.principal.id,
          uploaded,
          documentLabel,
          req.correlationId,
          printColorMode,
        );
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/otp-challenges/redeem',
    ...requireDevice(deps),
    validateBody(redeemOtpSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const result = await service.redeem(req.principal.deviceId, req.body, req.correlationId);
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/otp-challenges/:challengeId',
    authRequired(deps.config, ['citizen']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const challengeId = requireParam(req.params.challengeId, 'challengeId');
        const result = await service.getChallengeForCitizen(req.principal.id, challengeId);
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/otp-challenges/:challengeId/resend-otp',
    authRequired(deps.config, ['citizen']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const challengeId = requireParam(req.params.challengeId, 'challengeId');
        const result = await service.resendOtp(req.principal.id, challengeId, req.correlationId);
        res.json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/otp-challenges/:challengeId/documents/:documentId/content',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const challengeId = requireParam(req.params.challengeId, 'challengeId');
        const documentId = requireParam(req.params.documentId, 'documentId');
        const doc = await service.getDocumentContent(req.principal.deviceId, challengeId, documentId);
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
}

export { OtpPrintService } from './otp_print.service.js';
