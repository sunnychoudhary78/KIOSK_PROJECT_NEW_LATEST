-- CreateEnum
CREATE TYPE "DeviceSurveillanceCommandStatus" AS ENUM ('pending', 'running', 'succeeded', 'failed', 'expired');

-- CreateEnum
CREATE TYPE "DeviceSurveillanceCommandType" AS ENUM ('heal_queue', 'retry_uploads', 'prune_stubs');

-- CreateTable
CREATE TABLE "device_surveillance_commands" (
    "id" UUID NOT NULL,
    "device_id" UUID NOT NULL,
    "type" "DeviceSurveillanceCommandType" NOT NULL,
    "status" "DeviceSurveillanceCommandStatus" NOT NULL DEFAULT 'pending',
    "requested_by_user_id" UUID,
    "result_json" JSONB,
    "last_error" VARCHAR(500),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "acked_at" TIMESTAMP(3),
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "device_surveillance_commands_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "device_surveillance_commands_device_id_status_idx" ON "device_surveillance_commands"("device_id", "status");

-- CreateIndex
CREATE INDEX "device_surveillance_commands_expires_at_idx" ON "device_surveillance_commands"("expires_at");

-- AddForeignKey
ALTER TABLE "device_surveillance_commands" ADD CONSTRAINT "device_surveillance_commands_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "device_surveillance_commands" ADD CONSTRAINT "device_surveillance_commands_requested_by_user_id_fkey" FOREIGN KEY ("requested_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
