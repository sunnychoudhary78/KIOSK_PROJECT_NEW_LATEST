import type { NextFunction, Request, Response, Router } from 'express';
import multer from 'multer';
import { AdCampaignStatus, AdCreativeType, UserRole } from '@prisma/client';
import type { AppDeps } from '../../types/deps.js';
import { authRequired, requireAdminRole } from '../../shared/auth.js';
import { validateBody } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { requireParam } from '../../shared/params.js';
import { AdsService } from './ads.service.js';
import {
  createAdvertiserSchema,
  createCampaignSchema,
  reportAdEventsSchema,
  setCampaignCreativesSchema,
  setCampaignTargetsSchema,
  updateAdvertiserSchema,
  updateCampaignSchema,
} from './ads.schemas.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 80 * 1024 * 1024 },
});

export function registerAdsModule(router: Router, deps: AppDeps): void {
  const service = new AdsService(deps.db, deps.auditService);

  // --- Admin: advertisers ---
  router.get(
    '/ads/advertisers',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (_req, res, next) => {
      try {
        res.json(await service.listAdvertisers());
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/ads/advertisers/:id',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (req, res, next) => {
      try {
        res.json(await service.getAdvertiser(requireParam(req.params.id, 'id')));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/ads/advertisers',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    validateBody(createAdvertiserSchema),
    async (req, res, next) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.createAdvertiser(
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
    '/ads/advertisers/:id',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    validateBody(updateAdvertiserSchema),
    async (req, res, next) => {
      try {
        res.json(await service.updateAdvertiser(requireParam(req.params.id, 'id'), req.body));
      } catch (error) {
        next(error);
      }
    },
  );

  // --- Admin: creatives ---
  router.get(
    '/ads/creatives',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (req, res, next) => {
      try {
        const advertiserId =
          typeof req.query.advertiserId === 'string' ? req.query.advertiserId : undefined;
        res.json(await service.listCreatives(advertiserId));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/ads/creatives',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    upload.fields([
      { name: 'files', maxCount: 20 },
      { name: 'file', maxCount: 1 },
    ]),
    async (req, res, next) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const uploaded = req.files as
          | { [fieldname: string]: Express.Multer.File[] }
          | undefined;
        const files = [...(uploaded?.files ?? []), ...(uploaded?.file ?? [])];
        if (files.length === 0) {
          throw new AppError('validation_error', 'file(s) are required', 400);
        }
        const advertiserId = String(req.body.advertiserId ?? '');
        const title = String(req.body.title ?? '').trim();
        if (!advertiserId || !title) {
          throw new AppError('validation_error', 'advertiserId and title are required', 400);
        }
        const purposeRaw = String(req.body.purpose ?? '').trim().toLowerCase();
        const durationSec = req.body.durationSec
          ? Number.parseInt(String(req.body.durationSec), 10)
          : undefined;
        const duration = Number.isFinite(durationSec) ? durationSec : undefined;

        if (purposeRaw === 'idle' || purposeRaw === 'banner') {
          const result = await service.createCreativeFromFiles({
            advertiserId,
            title,
            purpose: purposeRaw,
            files,
            durationSec: duration,
            principalId: req.principal.id,
            correlationId: req.correlationId,
          });
          res.status(201).json(result);
          return;
        }

        // Legacy: explicit type + single file
        const typeRaw = String(req.body.type ?? 'image');
        if (!Object.values(AdCreativeType).includes(typeRaw as AdCreativeType)) {
          throw new AppError(
            'validation_error',
            'purpose (idle|banner) or a valid type is required',
            400,
          );
        }
        const result = await service.createCreativeFromUpload({
          advertiserId,
          title,
          type: typeRaw as AdCreativeType,
          durationSec: duration,
          file: files[0]!,
          principalId: req.principal.id,
          correlationId: req.correlationId,
        });
        res.status(201).json(result);
      } catch (error) {
        next(error);
      }
    },
  );

  router.delete(
    '/ads/creatives/:id',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    async (req, res, next) => {
      try {
        res.json(await service.deleteCreative(requireParam(req.params.id, 'id')));
      } catch (error) {
        next(error);
      }
    },
  );

  // --- Admin: campaigns ---
  router.get(
    '/ads/campaigns',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (_req, res, next) => {
      try {
        res.json(await service.listCampaigns());
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/ads/campaigns/:id',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (req, res, next) => {
      try {
        res.json(await service.getCampaign(requireParam(req.params.id, 'id')));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/ads/campaigns',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    validateBody(createCampaignSchema),
    async (req, res, next) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        const result = await service.createCampaign(
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
    '/ads/campaigns/:id',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    validateBody(updateCampaignSchema),
    async (req, res, next) => {
      try {
        res.json(await service.updateCampaign(requireParam(req.params.id, 'id'), req.body));
      } catch (error) {
        next(error);
      }
    },
  );

  router.put(
    '/ads/campaigns/:id/creatives',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    validateBody(setCampaignCreativesSchema),
    async (req, res, next) => {
      try {
        res.json(await service.setCampaignCreatives(requireParam(req.params.id, 'id'), req.body));
      } catch (error) {
        next(error);
      }
    },
  );

  router.put(
    '/ads/campaigns/:id/targets',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    validateBody(setCampaignTargetsSchema),
    async (req, res, next) => {
      try {
        res.json(await service.setCampaignTargets(requireParam(req.params.id, 'id'), req.body));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/ads/campaigns/:id/start',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    async (req, res, next) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        res.json(
          await service.setCampaignStatus(
            requireParam(req.params.id, 'id'),
            AdCampaignStatus.active,
            req.principal.id,
            req.correlationId,
          ),
        );
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/ads/campaigns/:id/pause',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    async (req, res, next) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        res.json(
          await service.setCampaignStatus(
            requireParam(req.params.id, 'id'),
            AdCampaignStatus.paused,
            req.principal.id,
            req.correlationId,
          ),
        );
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/ads/campaigns/:id/end',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator),
    async (req, res, next) => {
      try {
        if (!req.principal) {
          throw new AppError('unauthorized', 'Missing principal', 401);
        }
        res.json(
          await service.setCampaignStatus(
            requireParam(req.params.id, 'id'),
            AdCampaignStatus.ended,
            req.principal.id,
            req.correlationId,
          ),
        );
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/ads/sites',
    authRequired(deps.config, ['admin']),
    requireAdminRole(UserRole.admin, UserRole.operator, UserRole.viewer),
    async (_req, res, next) => {
      try {
        res.json(await service.listSites());
      } catch (error) {
        next(error);
      }
    },
  );

  // Media (admin + device) — asset route before :creativeId
  router.get(
    '/ads/media/asset/:assetId',
    authRequired(deps.config, ['admin', 'device']),
    async (req, res, next) => {
      try {
        const media = await service.getAssetMediaBuffer(requireParam(req.params.assetId, 'assetId'));
        res.setHeader('Content-Type', media.mimeType);
        res.setHeader('Cache-Control', 'private, max-age=300');
        res.send(media.bytes);
      } catch (error) {
        next(error);
      }
    },
  );

  router.get(
    '/ads/media/:creativeId',
    authRequired(deps.config, ['admin', 'device']),
    async (req, res, next) => {
      try {
        const media = await service.getMediaBuffer(requireParam(req.params.creativeId, 'creativeId'));
        res.setHeader('Content-Type', media.mimeType);
        res.setHeader('Cache-Control', 'private, max-age=300');
        res.send(media.bytes);
      } catch (error) {
        next(error);
      }
    },
  );

  // Device playlist + events
  router.get(
    '/ads/playlist',
    authRequired(deps.config, ['device']),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        res.json(await service.getPlaylistForDevice(req.principal.deviceId));
      } catch (error) {
        next(error);
      }
    },
  );

  router.post(
    '/ads/events',
    authRequired(deps.config, ['device']),
    validateBody(reportAdEventsSchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        res.status(202).json(await service.reportEvents(req.principal.deviceId, req.body));
      } catch (error) {
        next(error);
      }
    },
  );
}

export { AdsService } from './ads.service.js';
