-- CreateEnum
CREATE TYPE "SurveillanceSegmentStatus" AS ENUM ('pending_upload', 'uploaded');

-- CreateTable
CREATE TABLE "surveillance_segments" (
    "id" UUID NOT NULL,
    "device_id" UUID NOT NULL,
    "object_key" TEXT NOT NULL,
    "filename" TEXT NOT NULL,
    "byte_size" BIGINT NOT NULL,
    "content_type" TEXT NOT NULL DEFAULT 'video/mp4',
    "status" "SurveillanceSegmentStatus" NOT NULL DEFAULT 'pending_upload',
    "uploaded_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "surveillance_segments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "surveillance_segments_device_id_object_key_key" ON "surveillance_segments"("device_id", "object_key");

-- CreateIndex
CREATE INDEX "surveillance_segments_device_id_status_idx" ON "surveillance_segments"("device_id", "status");

-- AddForeignKey
ALTER TABLE "surveillance_segments" ADD CONSTRAINT "surveillance_segments_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
