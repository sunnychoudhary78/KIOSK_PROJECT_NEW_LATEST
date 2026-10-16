-- AlterEnum
ALTER TYPE "AdCreativeType" ADD VALUE 'banner_vertical';

-- AlterEnum
ALTER TYPE "AdSlot" ADD VALUE 'home_banner_vertical';

-- AlterTable
ALTER TABLE "devices" ADD COLUMN "banner_horizontal_enabled" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "devices" ADD COLUMN "banner_vertical_enabled" BOOLEAN NOT NULL DEFAULT true;
