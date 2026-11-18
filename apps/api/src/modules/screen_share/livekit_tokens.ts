import { AccessToken, RoomServiceClient } from 'livekit-server-sdk';
import type { AppConfig } from '../../config/index.js';

export type LiveKitTokenRole = 'publisher' | 'subscriber';

export function isLiveKitConfigured(config: AppConfig): boolean {
  return Boolean(config.livekit.url && config.livekit.apiKey && config.livekit.apiSecret);
}

/** Convert wss://host → https://host for RoomServiceClient. */
export function liveKitHttpHost(wssUrl: string): string {
  if (wssUrl.startsWith('wss://')) {
    return `https://${wssUrl.slice('wss://'.length)}`;
  }
  if (wssUrl.startsWith('ws://')) {
    return `http://${wssUrl.slice('ws://'.length)}`;
  }
  return wssUrl;
}

export async function mintLiveKitToken(input: {
  config: AppConfig;
  roomName: string;
  identity: string;
  role: LiveKitTokenRole;
  ttlSeconds: number;
}): Promise<string> {
  const { config, roomName, identity, role, ttlSeconds } = input;
  const at = new AccessToken(config.livekit.apiKey, config.livekit.apiSecret, {
    identity,
    ttl: ttlSeconds,
  });
  at.addGrant({
    roomJoin: true,
    room: roomName,
    canPublish: role === 'publisher',
    canSubscribe: role === 'subscriber',
    canPublishData: false,
  });
  return at.toJwt();
}

export async function deleteLiveKitRoom(config: AppConfig, roomName: string): Promise<void> {
  if (!isLiveKitConfigured(config)) {
    return;
  }
  const client = new RoomServiceClient(
    liveKitHttpHost(config.livekit.url),
    config.livekit.apiKey,
    config.livekit.apiSecret,
  );
  await client.deleteRoom(roomName);
}
