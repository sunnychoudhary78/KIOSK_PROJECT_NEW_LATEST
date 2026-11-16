-- Per-kiosk hardware snapshot from heartbeat (serial, shutter, sensors, charging).
ALTER TABLE "devices" ADD COLUMN IF NOT EXISTS "hardware_health" JSONB;
ALTER TABLE "devices" ADD COLUMN IF NOT EXISTS "hardware_health_at" TIMESTAMP(3);
