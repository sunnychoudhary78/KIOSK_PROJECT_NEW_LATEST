-- CreateTable
CREATE TABLE "service_ratings" (
    "id" UUID NOT NULL,
    "device_id" UUID NOT NULL,
    "service_key" VARCHAR(120) NOT NULL,
    "stars" INTEGER NOT NULL,
    "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "metadata" JSONB,

    CONSTRAINT "service_ratings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "service_ratings_device_id_occurred_at_idx" ON "service_ratings"("device_id", "occurred_at");

-- CreateIndex
CREATE INDEX "service_ratings_device_id_service_key_occurred_at_idx" ON "service_ratings"("device_id", "service_key", "occurred_at");

-- AddForeignKey
ALTER TABLE "service_ratings" ADD CONSTRAINT "service_ratings_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
