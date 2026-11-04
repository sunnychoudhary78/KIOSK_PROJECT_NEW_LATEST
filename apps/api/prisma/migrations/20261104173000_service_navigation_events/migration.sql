-- CreateTable
CREATE TABLE "service_navigation_events" (
    "id" UUID NOT NULL,
    "device_id" UUID NOT NULL,
    "event_key" VARCHAR(120) NOT NULL,
    "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "metadata" JSONB,

    CONSTRAINT "service_navigation_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "service_navigation_events_device_id_occurred_at_idx" ON "service_navigation_events"("device_id", "occurred_at");

-- CreateIndex
CREATE INDEX "service_navigation_events_device_id_event_key_occurred_at_idx" ON "service_navigation_events"("device_id", "event_key", "occurred_at");

-- AddForeignKey
ALTER TABLE "service_navigation_events" ADD CONSTRAINT "service_navigation_events_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
