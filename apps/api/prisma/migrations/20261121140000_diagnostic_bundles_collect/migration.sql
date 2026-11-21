-- AlterEnum
ALTER TYPE "DeviceSurveillanceCommandType" ADD VALUE 'collect_diagnostics';

-- CreateEnum
CREATE TYPE "DeviceDiagnosticBundleStatus" AS ENUM ('pending_upload', 'uploaded');

-- CreateTable
CREATE TABLE "device_diagnostic_bundles" (
    "id" UUID NOT NULL,
    "device_id" UUID NOT NULL,
    "command_id" UUID,
    "object_key" TEXT NOT NULL,
    "byte_size" BIGINT NOT NULL,
    "content_type" TEXT NOT NULL DEFAULT 'application/zip',
    "status" "DeviceDiagnosticBundleStatus" NOT NULL DEFAULT 'pending_upload',
    "uploaded_at" TIMESTAMP(3),
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "device_diagnostic_bundles_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "device_diagnostic_bundles_device_id_created_at_idx" ON "device_diagnostic_bundles"("device_id", "created_at");

-- CreateIndex
CREATE INDEX "device_diagnostic_bundles_expires_at_idx" ON "device_diagnostic_bundles"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "device_diagnostic_bundles_device_id_object_key_key" ON "device_diagnostic_bundles"("device_id", "object_key");

-- AddForeignKey
ALTER TABLE "device_diagnostic_bundles" ADD CONSTRAINT "device_diagnostic_bundles_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
