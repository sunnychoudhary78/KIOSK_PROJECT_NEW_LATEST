-- CreateEnum
CREATE TYPE "ScreenShareSessionStatus" AS ENUM ('pending', 'active', 'ended', 'expired', 'failed');

-- CreateTable
CREATE TABLE "screen_share_sessions" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "device_id" UUID NOT NULL,
    "room_name" VARCHAR(120) NOT NULL,
    "status" "ScreenShareSessionStatus" NOT NULL DEFAULT 'pending',
    "requested_by_user_id" UUID,
    "requested_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "started_at" TIMESTAMP(3),
    "ended_at" TIMESTAMP(3),
    "expires_at" TIMESTAMP(3) NOT NULL,
    "last_error" VARCHAR(500),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "screen_share_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "screen_share_sessions_device_id_status_idx" ON "screen_share_sessions"("device_id", "status");

-- CreateIndex
CREATE INDEX "screen_share_sessions_expires_at_idx" ON "screen_share_sessions"("expires_at");

-- AddForeignKey
ALTER TABLE "screen_share_sessions" ADD CONSTRAINT "screen_share_sessions_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "screen_share_sessions" ADD CONSTRAINT "screen_share_sessions_requested_by_user_id_fkey" FOREIGN KEY ("requested_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
