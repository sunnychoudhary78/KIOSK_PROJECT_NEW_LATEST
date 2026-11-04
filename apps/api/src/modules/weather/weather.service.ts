import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { GoogleWeatherClient, WeatherSnapshot } from './google_weather.client.js';

export class WeatherService {
  constructor(
    private readonly db: DbClient,
    private readonly googleWeather: GoogleWeatherClient,
  ) {}

  async forDevice(deviceId: string): Promise<WeatherSnapshot> {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { latitude: true, longitude: true },
    });
    if (!device || device.latitude == null || device.longitude == null) {
      throw new AppError('location_missing', 'This kiosk has no location set', 409);
    }

    try {
      return await this.googleWeather.getWeather(device.latitude, device.longitude);
    } catch {
      throw new AppError('weather_unavailable', 'Weather data is temporarily unavailable', 502);
    }
  }
}
