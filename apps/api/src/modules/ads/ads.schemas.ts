import { z } from 'zod';

export const createAdvertiserSchema = z.object({
  name: z.string().min(1).max(200),
  contactEmail: z.string().email().optional().nullable(),
  tenantId: z.string().uuid().optional(),
});

export const updateAdvertiserSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  contactEmail: z.string().email().optional().nullable(),
  isActive: z.boolean().optional(),
});

export const createCampaignSchema = z.object({
  advertiserId: z.string().uuid(),
  name: z.string().min(1).max(200),
  startsAt: z.string().datetime().optional().nullable(),
  endsAt: z.string().datetime().optional().nullable(),
  priority: z.number().int().min(0).max(1000).optional(),
});

export const updateCampaignSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  startsAt: z.string().datetime().optional().nullable(),
  endsAt: z.string().datetime().optional().nullable(),
  priority: z.number().int().min(0).max(1000).optional(),
});

export const setCampaignCreativesSchema = z.object({
  items: z
    .array(
      z.object({
        creativeId: z.string().uuid(),
        slot: z.enum(['idle_video', 'home_banner', 'home_carousel']),
        sortOrder: z.number().int().min(0).optional(),
        weight: z.number().int().min(1).max(100).optional(),
      }),
    )
    .min(1),
});

export const setCampaignTargetsSchema = z.object({
  targetAll: z.boolean().optional(),
  siteIds: z.array(z.string().uuid()).optional(),
  deviceIds: z.array(z.string().uuid()).optional(),
});

export const reportAdEventsSchema = z.object({
  events: z
    .array(
      z.object({
        campaignId: z.string().uuid(),
        creativeId: z.string().uuid(),
        eventType: z.enum(['impression', 'play_start', 'play_complete', 'click']),
        occurredAt: z.string().datetime().optional(),
        metadata: z.record(z.unknown()).optional(),
      }),
    )
    .min(1)
    .max(100),
});

export type CreateAdvertiserInput = z.infer<typeof createAdvertiserSchema>;
export type UpdateAdvertiserInput = z.infer<typeof updateAdvertiserSchema>;
export type CreateCampaignInput = z.infer<typeof createCampaignSchema>;
export type UpdateCampaignInput = z.infer<typeof updateCampaignSchema>;
export type SetCampaignCreativesInput = z.infer<typeof setCampaignCreativesSchema>;
export type SetCampaignTargetsInput = z.infer<typeof setCampaignTargetsSchema>;
export type ReportAdEventsInput = z.infer<typeof reportAdEventsSchema>;
