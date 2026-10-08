import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { ServicesCatalogService } from '../services/services.service.js';
import { pickApproachTargets } from './approach.js';
import type { ApproachTrafficClient } from './approach_traffic.client.js';
import { NEARBY_RADIUS_KM, rankNearbyStations, searchBox } from './nearby.js';
import type { FuelStationsQuery } from './fuel_stations.schemas.js';

export class FuelStationsService {
  constructor(
    private readonly db: DbClient,
    private readonly services: ServicesCatalogService,
    private readonly approachTraffic: ApproachTrafficClient,
  ) {}

  async nearby(deviceId: string, query: FuelStationsQuery) {
    await this.services.assertEnabled(deviceId, 'fuel_stations');

    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { latitude: true, longitude: true },
    });
    if (!device || device.latitude == null || device.longitude == null) {
      throw new AppError('location_missing', 'This kiosk has no location set', 409);
    }

    const box = searchBox(device.latitude, device.longitude, NEARBY_RADIUS_KM);
    const rows = await this.db.fuelStation.findMany({
      where: {
        isActive: true,
        latitude: { gte: box.minLat, lte: box.maxLat },
        longitude: { gte: box.minLng, lte: box.maxLng },
      },
      select: {
        name: true,
        address: true,
        latitude: true,
        longitude: true,
        petrol: true,
        diesel: true,
        cng: true,
        ev: true,
        fuelUntyped: true,
        googlePlaceId: true,
      },
    });

    const items = rankNearbyStations(
      rows,
      { lat: device.latitude, lng: device.longitude },
      query.kind,
      NEARBY_RADIUS_KM,
      query.limit,
    );

    const targets = pickApproachTargets(items);
    if (targets.length > 0) {
      const statuses = await Promise.all(
        targets.map(({ station }) =>
          this.approachTraffic.getApproachTraffic({
            lat: station.latitude,
            lng: station.longitude,
          }),
        ),
      );
      for (let i = 0; i < targets.length; i += 1) {
        const target = targets[i];
        const status = statuses[i];
        if (target && status) {
          items[target.index] = { ...items[target.index]!, approachTraffic: status };
        }
      }
    }

    return { items };
  }
}
