-- CreateEnum
CREATE TYPE "AdCreativeType" AS ENUM ('video', 'image', 'banner', 'carousel');

-- CreateEnum
CREATE TYPE "AdCampaignStatus" AS ENUM ('draft', 'scheduled', 'active', 'paused', 'ended');

-- CreateEnum
CREATE TYPE "AdSlot" AS ENUM ('idle_video', 'home_banner', 'home_carousel');

-- CreateEnum
CREATE TYPE "AdPlaybackEventType" AS ENUM ('impression', 'play_start', 'play_complete', 'click');

-- CreateTable
CREATE TABLE "advertisers" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "contact_email" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "advertisers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ad_creatives" (
    "id" UUID NOT NULL,
    "advertiser_id" UUID NOT NULL,
    "type" "AdCreativeType" NOT NULL,
    "title" TEXT NOT NULL,
    "storage_path" TEXT,
    "public_url" TEXT,
    "mime_type" TEXT,
    "duration_sec" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ad_creatives_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ad_creative_assets" (
    "id" UUID NOT NULL,
    "creative_id" UUID NOT NULL,
    "storage_path" TEXT NOT NULL,
    "public_url" TEXT,
    "mime_type" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ad_creative_assets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ad_campaigns" (
    "id" UUID NOT NULL,
    "advertiser_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "status" "AdCampaignStatus" NOT NULL DEFAULT 'draft',
    "starts_at" TIMESTAMP(3),
    "ends_at" TIMESTAMP(3),
    "priority" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ad_campaigns_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ad_campaign_creatives" (
    "id" UUID NOT NULL,
    "campaign_id" UUID NOT NULL,
    "creative_id" UUID NOT NULL,
    "slot" "AdSlot" NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "weight" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "ad_campaign_creatives_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ad_campaign_targets" (
    "id" UUID NOT NULL,
    "campaign_id" UUID NOT NULL,
    "target_all" BOOLEAN NOT NULL DEFAULT false,
    "site_id" UUID,
    "device_id" UUID,

    CONSTRAINT "ad_campaign_targets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ad_playback_events" (
    "id" UUID NOT NULL,
    "campaign_id" UUID NOT NULL,
    "creative_id" UUID NOT NULL,
    "device_id" UUID NOT NULL,
    "event_type" "AdPlaybackEventType" NOT NULL,
    "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "metadata" JSONB,

    CONSTRAINT "ad_playback_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "advertisers_tenant_id_idx" ON "advertisers"("tenant_id");

-- CreateIndex
CREATE INDEX "ad_creatives_advertiser_id_idx" ON "ad_creatives"("advertiser_id");

-- CreateIndex
CREATE INDEX "ad_creative_assets_creative_id_idx" ON "ad_creative_assets"("creative_id");

-- CreateIndex
CREATE INDEX "ad_campaigns_advertiser_id_status_idx" ON "ad_campaigns"("advertiser_id", "status");

-- CreateIndex
CREATE INDEX "ad_campaign_creatives_campaign_id_idx" ON "ad_campaign_creatives"("campaign_id");

-- CreateIndex
CREATE UNIQUE INDEX "ad_campaign_creatives_campaign_id_creative_id_slot_key" ON "ad_campaign_creatives"("campaign_id", "creative_id", "slot");

-- CreateIndex
CREATE INDEX "ad_campaign_targets_campaign_id_idx" ON "ad_campaign_targets"("campaign_id");

-- CreateIndex
CREATE INDEX "ad_playback_events_campaign_id_occurred_at_idx" ON "ad_playback_events"("campaign_id", "occurred_at");

-- CreateIndex
CREATE INDEX "ad_playback_events_device_id_occurred_at_idx" ON "ad_playback_events"("device_id", "occurred_at");

-- AddForeignKey
ALTER TABLE "advertisers" ADD CONSTRAINT "advertisers_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_creatives" ADD CONSTRAINT "ad_creatives_advertiser_id_fkey" FOREIGN KEY ("advertiser_id") REFERENCES "advertisers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_creative_assets" ADD CONSTRAINT "ad_creative_assets_creative_id_fkey" FOREIGN KEY ("creative_id") REFERENCES "ad_creatives"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_campaigns" ADD CONSTRAINT "ad_campaigns_advertiser_id_fkey" FOREIGN KEY ("advertiser_id") REFERENCES "advertisers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_campaign_creatives" ADD CONSTRAINT "ad_campaign_creatives_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "ad_campaigns"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_campaign_creatives" ADD CONSTRAINT "ad_campaign_creatives_creative_id_fkey" FOREIGN KEY ("creative_id") REFERENCES "ad_creatives"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_campaign_targets" ADD CONSTRAINT "ad_campaign_targets_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "ad_campaigns"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_campaign_targets" ADD CONSTRAINT "ad_campaign_targets_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "sites"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_campaign_targets" ADD CONSTRAINT "ad_campaign_targets_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_playback_events" ADD CONSTRAINT "ad_playback_events_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "ad_campaigns"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_playback_events" ADD CONSTRAINT "ad_playback_events_creative_id_fkey" FOREIGN KEY ("creative_id") REFERENCES "ad_creatives"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_playback_events" ADD CONSTRAINT "ad_playback_events_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
