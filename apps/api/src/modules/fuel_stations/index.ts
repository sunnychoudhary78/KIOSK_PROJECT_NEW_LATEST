import type { NextFunction, Request, Response, Router } from 'express';
import type { AppDeps } from '../../types/deps.js';
import { requireDevice } from '../../shared/device-guard.js';
import { validateQuery } from '../../infrastructure/http/validate.js';
import { AppError } from '../../shared/errors.js';
import { ServicesCatalogService } from '../services/services.service.js';
import { createApproachTrafficClient } from './approach_traffic.client.js';
import { fuelStationsQuerySchema, type FuelStationsQuery } from './fuel_stations.schemas.js';
import { FuelStationsService } from './fuel_stations.service.js';

export function registerFuelStationsModule(router: Router, deps: AppDeps): void {
  const services = new ServicesCatalogService(deps.db, deps.auditService);
  const approachTraffic = createApproachTrafficClient({
    apiKey: process.env.SKP_GOOGLE_PLACES_API_KEY,
  });
  const service = new FuelStationsService(deps.db, services, approachTraffic);

  router.get(
    '/fuel-stations',
    ...requireDevice(deps),
    validateQuery(fuelStationsQuerySchema),
    async (req: Request, res: Response, next: NextFunction) => {
      try {
        if (!req.principal?.deviceId) {
          throw new AppError('unauthorized', 'Missing device principal', 401);
        }
        const query = req.query as unknown as FuelStationsQuery;
        res.json(await service.nearby(req.principal.deviceId, query));
      } catch (error) {
        next(error);
      }
    },
  );
}
