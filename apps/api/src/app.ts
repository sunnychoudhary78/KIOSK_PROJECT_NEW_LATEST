import { readFile } from 'node:fs/promises';
import cors from 'cors';
import express, { Router, type Express } from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import type { AppDeps } from './types/deps.js';
import { correlationIdMiddleware } from './infrastructure/http/correlation.js';
import { errorHandler } from './infrastructure/http/error-handler.js';
import { authRequired } from './shared/auth.js';
import { AppError } from './shared/errors.js';
import { requireParam } from './shared/params.js';
import { registerIdentityModule } from './modules/identity/index.js';
import { registerDevicesModule } from './modules/devices/index.js';
import { registerServicesModule } from './modules/services/index.js';
import { registerAuditModule } from './modules/audit/index.js';
import { registerPrintingModule } from './modules/printing/index.js';
import { PrintingService } from './modules/printing/printing.service.js';
import { registerOtpPrintModule } from './modules/otp_print/index.js';
import {
  registerDigiLockerModule,
  registerDigiLockerOAuthCallback,
} from './modules/digilocker/index.js';
import { registerAdsModule } from './modules/ads/index.js';
import { registerPlatformSettingsModule } from './modules/platform_settings/index.js';

export function createApp(deps: AppDeps): Express {
  const app = express();

  app.disable('x-powered-by');
  app.use(
    helmet({
      contentSecurityPolicy: false,
    }),
  );
  app.use(
    cors({
      origin: deps.config.corsOrigins,
      credentials: true,
    }),
  );
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: false }));
  app.use(correlationIdMiddleware);
  app.use(
    rateLimit({
      windowMs: deps.config.rateLimit.windowMs,
      max: deps.config.rateLimit.max,
      standardHeaders: true,
      legacyHeaders: false,
      message: {
        code: 'rate_limited',
        message: 'Too many requests',
        correlationId: 'rate_limited',
      },
    }),
  );

  app.get('/v1/health', (_req, res) => {
    res.json({
      status: 'ok',
      service: 'skp-api',
      version: '0.1.0',
    });
  });

  // Exact DigiLocker registered redirect URI path
  app.get('/api/v1/auth/digilocker/callback', registerDigiLockerOAuthCallback(deps));

  const v1 = Router();
  registerIdentityModule(v1, deps);
  registerDevicesModule(v1, deps);
  registerServicesModule(v1, deps);
  registerAuditModule(v1, deps);
  registerPrintingModule(v1, deps);
  registerOtpPrintModule(v1, deps);
  registerDigiLockerModule(v1, deps);
  registerAdsModule(v1, deps);
  registerPlatformSettingsModule(v1, deps);

  // Device-authenticated PDF content for print jobs
  v1.get(
    '/print-jobs/:jobId/content',
    authRequired(deps.config, ['device']),
    async (req, res, next) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const printing = new PrintingService(deps.db, deps.auditService);
        const meta = await printing.getContentForDevice(
          requireParam(req.params.jobId, 'jobId'),
          req.principal.deviceId,
        );
        const bytes = await readFile(meta.payloadPath);
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader(
          'Content-Disposition',
          `inline; filename="${meta.title.replace(/"/g, '')}.pdf"`,
        );
        res.send(bytes);
      } catch (error) {
        next(error);
      }
    },
  );

  app.use('/v1', v1);
  app.use(errorHandler(deps.logger));

  return app;
}
