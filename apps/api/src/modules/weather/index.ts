import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { requireDevice } from '../../shared/device-guard.js';
import { AppError } from '../../shared/errors.js';
import { createOpenMeteoClient } from './open_meteo.client.js';
import { WeatherService } from './weather.service.js';

export function registerWeatherModule(router: Router, deps: AppDeps): void {
  const openMeteo = createOpenMeteoClient({ logger: deps.logger });
  const service = new WeatherService(deps.db, openMeteo);

  router.get(
    '/weather',
    ...requireDevice(deps),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        res.json(await service.forDevice(req.principal.deviceId));
      } catch (error) {
        next(error);
      }
    },
  );
}
