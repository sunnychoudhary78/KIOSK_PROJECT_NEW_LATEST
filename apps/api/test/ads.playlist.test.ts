import { describe, expect, it, vi } from 'vitest';
import { AdCampaignStatus, AdCreativeType, AdSlot } from '@prisma/client';
import { AdsService } from '../src/modules/ads/ads.service.js';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { AppError } from '../src/shared/errors.js';

const DEVICE_ID = '11111111-1111-1111-1111-111111111111';
const CAMPAIGN_ID = '22222222-2222-2222-2222-222222222222';
const HORIZONTAL_ID = '33333333-3333-3333-3333-333333333333';
const VERTICAL_ID = '44444444-4444-4444-4444-444444444444';

function creativeRow(id: string, type: AdCreativeType, title: string) {
  return {
    id,
    advertiserId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    type,
    title,
    storagePath: `/tmp/${id}.jpg`,
    publicUrl: `/ads/media/${id}`,
    mimeType: 'image/jpeg',
    durationSec: null,
    assets: [],
  };
}

function setup(deviceFlags: {
  bannerHorizontalEnabled?: boolean;
  bannerVerticalEnabled?: boolean;
}) {
  const horizontal = creativeRow(HORIZONTAL_ID, AdCreativeType.banner, 'H Banner');
  const vertical = creativeRow(VERTICAL_ID, AdCreativeType.banner_vertical, 'V Banner');

  const db = {
    device: {
      findUnique: vi.fn(async () => ({
        id: DEVICE_ID,
        siteId: 'site-1',
        bannerHorizontalEnabled: deviceFlags.bannerHorizontalEnabled ?? true,
        bannerVerticalEnabled: deviceFlags.bannerVerticalEnabled ?? true,
      })),
    },
    adCampaign: {
      findMany: vi.fn(async () => [
        {
          id: CAMPAIGN_ID,
          status: AdCampaignStatus.active,
          priority: 1,
          createdAt: new Date(),
          targets: [{ targetAll: true, deviceId: null, siteId: null }],
          creatives: [
            {
              slot: AdSlot.home_banner,
              sortOrder: 0,
              weight: 1,
              creative: horizontal,
            },
            {
              slot: AdSlot.home_banner_vertical,
              sortOrder: 0,
              weight: 1,
              creative: vertical,
            },
          ],
        },
      ]),
    },
    adCreative: {
      findMany: vi.fn(async ({ where }: { where: { id: { in: string[] } } }) =>
        [horizontal, vertical].filter((c) => where.id.in.includes(c.id)),
      ),
    },
    adCampaignCreative: {
      deleteMany: vi.fn(async () => ({ count: 0 })),
      createMany: vi.fn(async () => ({ count: 0 })),
    },
    $transaction: vi.fn(async (ops: unknown) => ops),
  };

  const audit = { record: vi.fn(async () => undefined) };
  const service = new AdsService(db as unknown as DbClient, audit as unknown as AuditService);
  return { service, db, horizontal, vertical };
}

describe('AdsService.getPlaylistForDevice', () => {
  it('returns horizontal and vertical banners when both enabled', async () => {
    const { service } = setup({});
    const playlist = await service.getPlaylistForDevice(DEVICE_ID);
    expect(playlist.homeBanners).toHaveLength(1);
    expect(playlist.homeBanners[0]?.id).toBe(HORIZONTAL_ID);
    expect(playlist.homeSideBanners).toHaveLength(1);
    expect(playlist.homeSideBanners[0]?.id).toBe(VERTICAL_ID);
  });

  it('omits horizontal banners when device disables them', async () => {
    const { service } = setup({ bannerHorizontalEnabled: false });
    const playlist = await service.getPlaylistForDevice(DEVICE_ID);
    expect(playlist.homeBanners).toEqual([]);
    expect(playlist.homeSideBanners).toHaveLength(1);
  });

  it('omits vertical banners when device disables them', async () => {
    const { service } = setup({ bannerVerticalEnabled: false });
    const playlist = await service.getPlaylistForDevice(DEVICE_ID);
    expect(playlist.homeBanners).toHaveLength(1);
    expect(playlist.homeSideBanners).toEqual([]);
  });
});

describe('AdsService.setCampaignCreatives slot/type validation', () => {
  it('rejects vertical creative in home_banner slot', async () => {
    const { service, db } = setup({});
    db.adCampaign = {
      ...db.adCampaign,
      findUnique: vi.fn(async () => ({ id: CAMPAIGN_ID })),
    } as typeof db.adCampaign;

    // requireCampaign uses findUnique
    (db as { adCampaign: Record<string, unknown> }).adCampaign.findUnique = vi.fn(
      async () => ({ id: CAMPAIGN_ID }),
    );

    await expect(
      service.setCampaignCreatives(CAMPAIGN_ID, {
        items: [{ creativeId: VERTICAL_ID, slot: 'home_banner' }],
      }),
    ).rejects.toBeInstanceOf(AppError);
  });

  it('rejects horizontal creative in home_banner_vertical slot', async () => {
    const { service, db } = setup({});
    (db as { adCampaign: Record<string, unknown> }).adCampaign.findUnique = vi.fn(
      async () => ({ id: CAMPAIGN_ID }),
    );

    await expect(
      service.setCampaignCreatives(CAMPAIGN_ID, {
        items: [{ creativeId: HORIZONTAL_ID, slot: 'home_banner_vertical' }],
      }),
    ).rejects.toBeInstanceOf(AppError);
  });
});
