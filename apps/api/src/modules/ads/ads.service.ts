import { mkdir, readFile, unlink } from 'node:fs/promises';
import { join, extname } from 'node:path';
import { randomUUID } from 'node:crypto';
import {
  AdCampaignStatus,
  AdCreativeType,
  AdPlaybackEventType,
  AdSlot,
  type Prisma,
} from '@prisma/client';
import type { DbClient } from '../../infrastructure/database/prisma.js';
import { AppError } from '../../shared/errors.js';
import type { AuditService } from '../audit/audit.service.js';
import type {
  CreateAdvertiserInput,
  CreateCampaignInput,
  ReportAdEventsInput,
  SetCampaignCreativesInput,
  SetCampaignTargetsInput,
  UpdateAdvertiserInput,
  UpdateCampaignInput,
} from './ads.schemas.js';

const ADS_UPLOAD_DIR = join(process.cwd(), 'uploads', 'ads');

function mapAdvertiser(row: {
  id: string;
  name: string;
  contactEmail: string | null;
  isActive: boolean;
  tenantId: string;
  createdAt: Date;
}) {
  return {
    id: row.id,
    name: row.name,
    contactEmail: row.contactEmail,
    isActive: row.isActive,
    tenantId: row.tenantId,
    createdAt: row.createdAt.toISOString(),
  };
}

function mapCreative(row: {
  id: string;
  advertiserId: string;
  type: AdCreativeType;
  title: string;
  storagePath: string | null;
  publicUrl: string | null;
  mimeType: string | null;
  durationSec: number | null;
  assets?: Array<{
    id: string;
    publicUrl: string | null;
    mimeType: string | null;
    sortOrder: number;
  }>;
}) {
  const fallbackMedia = row.storagePath ? `/ads/media/${row.id}` : null;
  return {
    id: row.id,
    advertiserId: row.advertiserId,
    type: row.type,
    title: row.title,
    mediaUrl: normalizeAdsMediaPath(row.publicUrl) ?? fallbackMedia,
    mimeType: row.mimeType,
    durationSec: row.durationSec,
    assets: (row.assets ?? []).map((a) => ({
      id: a.id,
      mediaUrl: normalizeAdsMediaPath(a.publicUrl) ?? `/ads/media/asset/${a.id}`,
      mimeType: a.mimeType,
      sortOrder: a.sortOrder,
    })),
  };
}

/** Strip legacy `/v1` prefix so clients with apiBaseUrl ending in `/v1` resolve correctly. */
function normalizeAdsMediaPath(url: string | null | undefined): string | null {
  if (!url) {
    return null;
  }
  if (url.startsWith('/v1/')) {
    return url.slice(3);
  }
  return url;
}

export class AdsService {
  constructor(
    private readonly db: DbClient,
    private readonly audit: AuditService,
  ) {}

  private async defaultTenantId(tenantId?: string) {
    if (tenantId) {
      return tenantId;
    }
    const tenant = await this.db.tenant.findUnique({ where: { code: 'default' } });
    if (!tenant) {
      throw new AppError('tenant_missing', 'Default tenant not found', 500);
    }
    return tenant.id;
  }

  async listAdvertisers() {
    const items = await this.db.advertiser.findMany({ orderBy: { createdAt: 'desc' } });
    return { items: items.map(mapAdvertiser) };
  }

  async getAdvertiser(id: string) {
    const row = await this.db.advertiser.findUnique({
      where: { id },
      include: {
        _count: { select: { creatives: true, campaigns: true } },
      },
    });
    if (!row) {
      throw new AppError('not_found', 'Advertiser not found', 404);
    }
    return {
      ...mapAdvertiser(row),
      creativeCount: row._count.creatives,
      campaignCount: row._count.campaigns,
    };
  }

  async createAdvertiser(
    input: CreateAdvertiserInput,
    principalId: string,
    correlationId?: string,
  ) {
    const tenantId = await this.defaultTenantId(input.tenantId);
    const row = await this.db.advertiser.create({
      data: {
        tenantId,
        name: input.name.trim(),
        contactEmail: input.contactEmail ?? null,
      },
    });
    await this.audit.record({
      action: 'ads.advertiser_created',
      principalType: 'admin',
      principalId,
      resourceType: 'advertiser',
      resourceId: row.id,
      correlationId,
    });
    return mapAdvertiser(row);
  }

  async updateAdvertiser(id: string, input: UpdateAdvertiserInput) {
    const existing = await this.db.advertiser.findUnique({ where: { id } });
    if (!existing) {
      throw new AppError('not_found', 'Advertiser not found', 404);
    }
    const row = await this.db.advertiser.update({
      where: { id },
      data: {
        name: input.name?.trim(),
        contactEmail: input.contactEmail === undefined ? undefined : input.contactEmail,
        isActive: input.isActive,
      },
    });
    return mapAdvertiser(row);
  }

  async listCreatives(advertiserId?: string) {
    const items = await this.db.adCreative.findMany({
      where: advertiserId ? { advertiserId } : undefined,
      include: { assets: { orderBy: { sortOrder: 'asc' } } },
      orderBy: { createdAt: 'desc' },
    });
    return { items: items.map(mapCreative) };
  }

  async createCreativeFromUpload(input: {
    advertiserId: string;
    title: string;
    type: AdCreativeType;
    durationSec?: number;
    file: Express.Multer.File;
    principalId: string;
    correlationId?: string;
  }) {
    return this.createCreativeFromFiles({
      advertiserId: input.advertiserId,
      title: input.title,
      purpose: input.type === AdCreativeType.banner ? 'banner' : 'idle',
      files: [input.file],
      durationSec: input.durationSec,
      principalId: input.principalId,
      correlationId: input.correlationId,
      forcedType: input.type,
    });
  }

  async createCreativeFromFiles(input: {
    advertiserId: string;
    title: string;
    purpose: 'idle' | 'banner';
    files: Express.Multer.File[];
    durationSec?: number;
    principalId: string;
    correlationId?: string;
    /** Legacy single-file type override when purpose is not sent by client. */
    forcedType?: AdCreativeType;
  }) {
    const advertiser = await this.db.advertiser.findUnique({ where: { id: input.advertiserId } });
    if (!advertiser) {
      throw new AppError('not_found', 'Advertiser not found', 404);
    }

    const files = input.files.filter(Boolean);
    if (files.length === 0) {
      throw new AppError('validation_error', 'At least one file is required', 400);
    }

    const isVideo = (f: Express.Multer.File) => f.mimetype.startsWith('video/');
    const isImage = (f: Express.Multer.File) => f.mimetype.startsWith('image/');

    let type: AdCreativeType;
    if (input.forcedType && input.purpose === 'idle' && files.length === 1) {
      type = input.forcedType;
    } else if (input.purpose === 'banner') {
      if (files.length !== 1 || !isImage(files[0]!)) {
        throw new AppError(
          'validation_error',
          'Home banner requires exactly one image file',
          400,
        );
      }
      type = AdCreativeType.banner;
    } else {
      const videos = files.filter(isVideo);
      const images = files.filter(isImage);
      if (videos.length > 0 && images.length > 0) {
        throw new AppError(
          'validation_error',
          'Idle media must be either one video or one or more photos, not both',
          400,
        );
      }
      if (videos.length > 0) {
        if (videos.length !== 1 || files.length !== 1) {
          throw new AppError('validation_error', 'Idle video accepts exactly one video file', 400);
        }
        type = AdCreativeType.video;
      } else if (images.length > 0) {
        type = images.length === 1 ? AdCreativeType.image : AdCreativeType.carousel;
      } else {
        throw new AppError(
          'validation_error',
          'Idle media requires a video or image file(s)',
          400,
        );
      }
    }

    await mkdir(ADS_UPLOAD_DIR, { recursive: true });
    const { writeFile } = await import('node:fs/promises');

    if (type === AdCreativeType.carousel) {
      const creativeId = randomUUID();
      const assetRows: Array<{
        id: string;
        storagePath: string;
        publicUrl: string;
        mimeType: string;
        sortOrder: number;
      }> = [];

      for (let i = 0; i < files.length; i += 1) {
        const file = files[i]!;
        const assetId = randomUUID();
        const ext = extname(file.originalname) || '';
        const storagePath = join(ADS_UPLOAD_DIR, `${assetId}${ext}`);
        await writeFile(storagePath, file.buffer);
        assetRows.push({
          id: assetId,
          storagePath,
          publicUrl: `/ads/media/asset/${assetId}`,
          mimeType: file.mimetype,
          sortOrder: i,
        });
      }

      const first = assetRows[0]!;
      const row = await this.db.adCreative.create({
        data: {
          id: creativeId,
          advertiserId: input.advertiserId,
          type,
          title: input.title.trim(),
          storagePath: null,
          publicUrl: first.publicUrl,
          mimeType: first.mimeType,
          durationSec: input.durationSec ?? 6,
          assets: {
            create: assetRows.map((a) => ({
              id: a.id,
              storagePath: a.storagePath,
              publicUrl: a.publicUrl,
              mimeType: a.mimeType,
              sortOrder: a.sortOrder,
            })),
          },
        },
        include: { assets: { orderBy: { sortOrder: 'asc' } } },
      });

      await this.audit.record({
        action: 'ads.creative_uploaded',
        principalType: 'admin',
        principalId: input.principalId,
        resourceType: 'ad_creative',
        resourceId: row.id,
        correlationId: input.correlationId,
        metadata: { type, purpose: input.purpose, assetCount: assetRows.length },
      });

      return mapCreative(row);
    }

    const file = files[0]!;
    const id = randomUUID();
    const ext = extname(file.originalname) || '';
    const storagePath = join(ADS_UPLOAD_DIR, `${id}${ext}`);
    await writeFile(storagePath, file.buffer);
    const publicUrl = `/ads/media/${id}`;

    const row = await this.db.adCreative.create({
      data: {
        id,
        advertiserId: input.advertiserId,
        type,
        title: input.title.trim(),
        storagePath,
        publicUrl,
        mimeType: file.mimetype,
        durationSec: input.durationSec ?? (type === AdCreativeType.image ? 6 : null),
      },
      include: { assets: { orderBy: { sortOrder: 'asc' } } },
    });

    await this.audit.record({
      action: 'ads.creative_uploaded',
      principalType: 'admin',
      principalId: input.principalId,
      resourceType: 'ad_creative',
      resourceId: row.id,
      correlationId: input.correlationId,
      metadata: { type, purpose: input.purpose, mimeType: file.mimetype },
    });

    return mapCreative(row);
  }

  async deleteCreative(id: string) {
    const row = await this.db.adCreative.findUnique({ where: { id }, include: { assets: true } });
    if (!row) {
      throw new AppError('not_found', 'Creative not found', 404);
    }
    await this.db.adCreative.delete({ where: { id } });
    if (row.storagePath) {
      await unlink(row.storagePath).catch(() => undefined);
    }
    for (const asset of row.assets) {
      await unlink(asset.storagePath).catch(() => undefined);
    }
    return { ok: true };
  }

  async getMediaBuffer(creativeId: string) {
    const row = await this.db.adCreative.findUnique({ where: { id: creativeId } });
    if (!row?.storagePath) {
      throw new AppError('not_found', 'Media not found', 404);
    }
    const bytes = await readFile(row.storagePath);
    return { bytes, mimeType: row.mimeType ?? 'application/octet-stream', title: row.title };
  }

  async getAssetMediaBuffer(assetId: string) {
    const row = await this.db.adCreativeAsset.findUnique({ where: { id: assetId } });
    if (!row) {
      throw new AppError('not_found', 'Asset not found', 404);
    }
    const bytes = await readFile(row.storagePath);
    return { bytes, mimeType: row.mimeType ?? 'application/octet-stream' };
  }

  async listCampaigns() {
    const items = await this.db.adCampaign.findMany({
      include: {
        advertiser: true,
        creatives: { include: { creative: true } },
        targets: true,
        _count: { select: { events: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return {
      items: items.map((c) => this.mapCampaign(c)),
    };
  }

  async getCampaign(id: string) {
    const c = await this.db.adCampaign.findUnique({
      where: { id },
      include: {
        advertiser: true,
        creatives: { include: { creative: { include: { assets: true } } } },
        targets: { include: { site: true, device: true } },
      },
    });
    if (!c) {
      throw new AppError('not_found', 'Campaign not found', 404);
    }
    const analytics = await this.campaignAnalytics(id);
    return { ...this.mapCampaign(c), analytics };
  }

  async createCampaign(input: CreateCampaignInput, principalId: string, correlationId?: string) {
    const advertiser = await this.db.advertiser.findUnique({ where: { id: input.advertiserId } });
    if (!advertiser) {
      throw new AppError('not_found', 'Advertiser not found', 404);
    }
    const row = await this.db.adCampaign.create({
      data: {
        advertiserId: input.advertiserId,
        name: input.name.trim(),
        startsAt: input.startsAt ? new Date(input.startsAt) : null,
        endsAt: input.endsAt ? new Date(input.endsAt) : null,
        priority: input.priority ?? 0,
        status: AdCampaignStatus.draft,
      },
      include: {
        advertiser: true,
        creatives: { include: { creative: true } },
        targets: true,
      },
    });
    await this.audit.record({
      action: 'ads.campaign_created',
      principalType: 'admin',
      principalId,
      resourceType: 'ad_campaign',
      resourceId: row.id,
      correlationId,
    });
    return this.mapCampaign(row);
  }

  async updateCampaign(id: string, input: UpdateCampaignInput) {
    await this.requireCampaign(id);
    const row = await this.db.adCampaign.update({
      where: { id },
      data: {
        name: input.name?.trim(),
        startsAt:
          input.startsAt === undefined
            ? undefined
            : input.startsAt
              ? new Date(input.startsAt)
              : null,
        endsAt:
          input.endsAt === undefined ? undefined : input.endsAt ? new Date(input.endsAt) : null,
        priority: input.priority,
      },
      include: {
        advertiser: true,
        creatives: { include: { creative: true } },
        targets: true,
      },
    });
    return this.mapCampaign(row);
  }

  async setCampaignCreatives(id: string, input: SetCampaignCreativesInput) {
    await this.requireCampaign(id);
    await this.db.$transaction([
      this.db.adCampaignCreative.deleteMany({ where: { campaignId: id } }),
      this.db.adCampaignCreative.createMany({
        data: input.items.map((item, index) => ({
          campaignId: id,
          creativeId: item.creativeId,
          slot: item.slot as AdSlot,
          sortOrder: item.sortOrder ?? index,
          weight: item.weight ?? 1,
        })),
      }),
    ]);
    return this.getCampaign(id);
  }

  async setCampaignTargets(id: string, input: SetCampaignTargetsInput) {
    await this.requireCampaign(id);
    const rows: Prisma.AdCampaignTargetCreateManyInput[] = [];
    if (input.targetAll) {
      rows.push({ campaignId: id, targetAll: true });
    }
    for (const siteId of input.siteIds ?? []) {
      rows.push({ campaignId: id, targetAll: false, siteId });
    }
    for (const deviceId of input.deviceIds ?? []) {
      rows.push({ campaignId: id, targetAll: false, deviceId });
    }
    if (rows.length === 0) {
      throw new AppError('validation_error', 'Select targetAll, sites, or devices', 400);
    }
    await this.db.$transaction([
      this.db.adCampaignTarget.deleteMany({ where: { campaignId: id } }),
      this.db.adCampaignTarget.createMany({ data: rows }),
    ]);
    return this.getCampaign(id);
  }

  async setCampaignStatus(
    id: string,
    status: AdCampaignStatus,
    principalId: string,
    correlationId?: string,
  ) {
    const campaign = await this.requireCampaign(id);
    if (status === AdCampaignStatus.active) {
      const creatives = await this.db.adCampaignCreative.count({ where: { campaignId: id } });
      const targets = await this.db.adCampaignTarget.count({ where: { campaignId: id } });
      if (creatives === 0) {
        throw new AppError('validation_error', 'Attach at least one creative before starting', 400);
      }
      if (targets === 0) {
        throw new AppError('validation_error', 'Set targeting before starting', 400);
      }
    }
    const row = await this.db.adCampaign.update({
      where: { id },
      data: { status },
      include: {
        advertiser: true,
        creatives: { include: { creative: true } },
        targets: true,
      },
    });
    await this.audit.record({
      action: `ads.campaign_${status}`,
      principalType: 'admin',
      principalId,
      resourceType: 'ad_campaign',
      resourceId: campaign.id,
      correlationId,
    });
    return this.mapCampaign(row);
  }

  async campaignAnalytics(campaignId: string) {
    const grouped = await this.db.adPlaybackEvent.groupBy({
      by: ['eventType'],
      where: { campaignId },
      _count: { _all: true },
    });
    const counts: Record<string, number> = {
      impression: 0,
      play_start: 0,
      play_complete: 0,
      click: 0,
    };
    for (const row of grouped) {
      counts[row.eventType] = row._count._all;
    }
    return counts;
  }

  async listSites() {
    const items = await this.db.site.findMany({
      orderBy: { name: 'asc' },
      include: { _count: { select: { devices: true } } },
    });
    return {
      items: items.map((s) => ({
        id: s.id,
        name: s.name,
        deviceCount: s._count.devices,
      })),
    };
  }

  async getPlaylistForDevice(deviceId: string) {
    const device = await this.db.device.findUnique({ where: { id: deviceId } });
    if (!device) {
      throw new AppError('not_found', 'Device not found', 404);
    }

    const now = new Date();
    const campaigns = await this.db.adCampaign.findMany({
      where: {
        status: AdCampaignStatus.active,
        OR: [{ startsAt: null }, { startsAt: { lte: now } }],
        AND: [{ OR: [{ endsAt: null }, { endsAt: { gte: now } }] }],
      },
      include: {
        targets: true,
        creatives: {
          include: { creative: { include: { assets: { orderBy: { sortOrder: 'asc' } } } } },
          orderBy: { sortOrder: 'asc' },
        },
      },
      orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
    });

    const matched = campaigns.filter((campaign) =>
      campaign.targets.some((t) => {
        if (t.targetAll) {
          return true;
        }
        if (t.deviceId && t.deviceId === device.id) {
          return true;
        }
        if (t.siteId && t.siteId === device.siteId) {
          return true;
        }
        return false;
      }),
    );

    const idle: ReturnType<typeof mapCreative>[] = [];
    const banners: ReturnType<typeof mapCreative>[] = [];
    const carousels: ReturnType<typeof mapCreative>[] = [];

    for (const campaign of matched) {
      for (const link of campaign.creatives) {
        const item = {
          ...mapCreative(link.creative),
          campaignId: campaign.id,
          slot: link.slot,
          sortOrder: link.sortOrder,
          weight: link.weight,
        };
        if (link.slot === AdSlot.idle_video) {
          idle.push(item);
        } else if (link.slot === AdSlot.home_banner) {
          banners.push(item);
        } else if (link.slot === AdSlot.home_carousel) {
          carousels.push(item);
        }
      }
    }

    return {
      idle,
      homeBanners: banners,
      homeCarousels: carousels,
      fetchedAt: now.toISOString(),
    };
  }

  async reportEvents(deviceId: string, input: ReportAdEventsInput) {
    const data = input.events.map((event) => ({
      campaignId: event.campaignId,
      creativeId: event.creativeId,
      deviceId,
      eventType: event.eventType as AdPlaybackEventType,
      occurredAt: event.occurredAt ? new Date(event.occurredAt) : new Date(),
      metadata: (event.metadata as Prisma.InputJsonValue) ?? undefined,
    }));
    await this.db.adPlaybackEvent.createMany({ data });
    return { accepted: data.length };
  }

  private async requireCampaign(id: string) {
    const campaign = await this.db.adCampaign.findUnique({ where: { id } });
    if (!campaign) {
      throw new AppError('not_found', 'Campaign not found', 404);
    }
    return campaign;
  }

  private mapCampaign(c: {
    id: string;
    name: string;
    status: AdCampaignStatus;
    startsAt: Date | null;
    endsAt: Date | null;
    priority: number;
    advertiserId: string;
    createdAt?: Date;
    updatedAt?: Date;
    advertiser?: { id: string; name: string };
    creatives?: Array<{
      slot: AdSlot;
      sortOrder: number;
      weight: number;
      creative: Parameters<typeof mapCreative>[0];
    }>;
    targets?: Array<{
      id: string;
      targetAll: boolean;
      siteId: string | null;
      deviceId: string | null;
      site?: { id: string; name: string } | null;
      device?: { id: string; name: string } | null;
    }>;
    _count?: { events: number };
  }) {
    return {
      id: c.id,
      name: c.name,
      status: c.status,
      startsAt: c.startsAt?.toISOString() ?? null,
      endsAt: c.endsAt?.toISOString() ?? null,
      priority: c.priority,
      advertiserId: c.advertiserId,
      advertiserName: c.advertiser?.name,
      createdAt: c.createdAt?.toISOString(),
      updatedAt: c.updatedAt?.toISOString(),
      creatives: (c.creatives ?? []).map((link) => ({
        slot: link.slot,
        sortOrder: link.sortOrder,
        weight: link.weight,
        creative: mapCreative(link.creative),
      })),
      targets: (c.targets ?? []).map((t) => ({
        id: t.id,
        targetAll: t.targetAll,
        siteId: t.siteId,
        deviceId: t.deviceId,
        siteName: t.site?.name,
        deviceName: t.device?.name,
      })),
      eventCount: c._count?.events,
    };
  }
}
