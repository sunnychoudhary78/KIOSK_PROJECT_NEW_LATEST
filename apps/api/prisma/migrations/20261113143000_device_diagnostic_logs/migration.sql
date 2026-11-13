-- CreateTable
CREATE TABLE "device_diagnostic_logs" (
    "id" UUID NOT NULL,
    "device_id" UUID NOT NULL,
    "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "level" VARCHAR(16) NOT NULL,
    "category" VARCHAR(40) NOT NULL,
    "event" VARCHAR(120) NOT NULL,
    "message" VARCHAR(500) NOT NULL,
    "correlation_id" VARCHAR(64),
    "metadata" JSONB,

    CONSTRAINT "device_diagnostic_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "device_diagnostic_logs_device_id_occurred_at_idx" ON "device_diagnostic_logs"("device_id", "occurred_at");

-- CreateIndex
CREATE INDEX "device_diagnostic_logs_device_id_category_occurred_at_idx" ON "device_diagnostic_logs"("device_id", "category", "occurred_at");

-- CreateIndex
CREATE INDEX "device_diagnostic_logs_occurred_at_idx" ON "device_diagnostic_logs"("occurred_at");

-- AddForeignKey
ALTER TABLE "device_diagnostic_logs" ADD CONSTRAINT "device_diagnostic_logs_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
