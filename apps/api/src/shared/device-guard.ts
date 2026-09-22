import type { NextFunction, Request, Response } from 'express';
import { DeviceStatus } from '@prisma/client';
import type { DbClient } from '../infrastructure/database/prisma.js';
import type { AppDeps } from '../types/deps.js';
import { authRequired } from './auth.js';
import { AppError } from './errors.js';

export function assertActiveDevice(db: DbClient) {
  return async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
    try {
      if (req.principal?.type !== 'device') {
        next();
        return;
      }
      const deviceId = req.principal.deviceId ?? req.principal.id;
      if (!deviceId) {
        next(new AppError('unauthorized', 'Missing device principal', 401));
        return;
      }
      const device = await db.device.findUnique({
        where: { id: deviceId },
        select: { status: true },
      });
      if (!device || device.status === DeviceStatus.inactive) {
        next(new AppError('device_inactive', 'This kiosk has been stopped', 403));
        return;
      }
      next();
    } catch (error) {
      next(error);
    }
  };
}

export function requireDevice(deps: AppDeps) {
  return [authRequired(deps.config, ['device']), assertActiveDevice(deps.db)];
}
