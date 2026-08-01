export type Advertiser = {
  id: string;
  name: string;
  contactEmail: string | null;
  isActive: boolean;
  tenantId?: string;
  createdAt?: string;
  creativeCount?: number;
  campaignCount?: number;
};

export type CreativeAsset = {
  id: string;
  mediaUrl: string | null;
  mimeType?: string | null;
  sortOrder: number;
};

export type Creative = {
  id: string;
  advertiserId: string;
  type: string;
  title: string;
  mediaUrl: string | null;
  mimeType?: string | null;
  durationSec?: number | null;
  assets?: CreativeAsset[];
};

export type Device = { id: string; name: string; siteName: string };
export type Site = { id: string; name: string; deviceCount: number };

export type Campaign = {
  id: string;
  name: string;
  status: string;
  advertiserId: string;
  advertiserName?: string;
  priority: number;
  startsAt?: string | null;
  endsAt?: string | null;
  eventCount?: number;
  createdAt?: string;
  updatedAt?: string;
  analytics?: Record<string, number>;
  creatives?: Array<{ slot: string; creative: Creative }>;
  targets?: Array<{
    targetAll: boolean;
    siteId?: string | null;
    deviceId?: string | null;
    siteName?: string;
    deviceName?: string;
  }>;
};

export function formatDate(value?: string | null): string {
  if (!value) {
    return '—';
  }
  try {
    return new Date(value).toLocaleString();
  } catch {
    return value;
  }
}
