-- CreateEnum
CREATE TYPE "KioskAppReleaseStatus" AS ENUM ('pending_upload', 'uploaded', 'active');

-- CreateTable
CREATE TABLE "kiosk_app_releases" (
    "id" UUID NOT NULL,
    "version" VARCHAR(64) NOT NULL,
    "object_key" TEXT NOT NULL,
    "content_type" TEXT NOT NULL DEFAULT 'application/zip',
    "byte_size" BIGINT NOT NULL,
    "sha256" VARCHAR(64) NOT NULL,
    "status" "KioskAppReleaseStatus" NOT NULL DEFAULT 'pending_upload',
    "created_by_admin_id" UUID,
    "uploaded_at" TIMESTAMP(3),
    "activated_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "kiosk_app_releases_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "kiosk_app_releases_version_key" ON "kiosk_app_releases"("version");

-- CreateIndex
CREATE INDEX "kiosk_app_releases_status_idx" ON "kiosk_app_releases"("status");

-- CreateIndex
CREATE INDEX "kiosk_app_releases_created_at_idx" ON "kiosk_app_releases"("created_at");
