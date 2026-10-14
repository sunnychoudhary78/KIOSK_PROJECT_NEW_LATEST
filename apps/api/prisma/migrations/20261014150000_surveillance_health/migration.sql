-- AlterTable
ALTER TABLE "devices" ADD COLUMN "surveillance_health" JSONB;
ALTER TABLE "devices" ADD COLUMN "surveillance_health_at" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "surveillance_segments" ADD COLUMN "last_upload_error" TEXT;
