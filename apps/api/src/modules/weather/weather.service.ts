import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import {
  clampHistoryHours,
  type AirQualityDetail,
  type AirQualityHistory,
  type GoogleWeatherClient,
  type WeatherSnapshot,
} from './google_weather.client.js';

export class WeatherService {
  constructor(
    private readonly db: DbClient,
    private readonly googleWeather: GoogleWeatherClient,
  ) {}

  async forDevice(deviceId: string): Promise<WeatherSnapshot> {
    const coords = await this.coordsForDevice(deviceId);
    try {
      return await this.googleWeather.getWeather(coords.latitude, coords.longitude);
    } catch {
      throw new AppError('weather_unavailable', 'Weather data is temporarily unavailable', 502);
    }
  }

  async airQualityForDevice(deviceId: string): Promise<AirQualityDetail> {
    const coords = await this.coordsForDevice(deviceId);
    try {
      return await this.googleWeather.getAirQualityDetail(coords.latitude, coords.longitude);
    } catch {
      throw new AppError('weather_unavailable', 'Air quality data is temporarily unavailable', 502);
    }
  }

  async airQualityHistoryForDevice(
    deviceId: string,
    hours?: number,
  ): Promise<AirQualityHistory> {
    const coords = await this.coordsForDevice(deviceId);
    const clamped = clampHistoryHours(hours ?? 24);
    try {
      return await this.googleWeather.getAirQualityHistory(
        coords.latitude,
        coords.longitude,
        clamped,
      );
    } catch {
      throw new AppError(
        'weather_unavailable',
        'Air quality history is temporarily unavailable',
        502,
      );
    }
  }

  private async coordsForDevice(
    deviceId: string,
  ): Promise<{ latitude: number; longitude: number }> {
    const device = await this.db.device.findUnique({
      where: { id: deviceId },
      select: { latitude: true, longitude: true },
    });
    if (!device || device.latitude == null || device.longitude == null) {
      throw new AppError('location_missing', 'This kiosk has no location set', 409);
    }
    return { latitude: device.latitude, longitude: device.longitude };
  }
}
