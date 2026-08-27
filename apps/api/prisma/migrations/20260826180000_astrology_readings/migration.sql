-- CreateTable
CREATE TABLE "astrology_readings" (
    "id" UUID NOT NULL,
    "device_id" UUID NOT NULL,
    "subject" JSONB NOT NULL,
    "chart" JSONB NOT NULL,
    "palm" JSONB NOT NULL,
    "reading" JSONB NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "astrology_readings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "astrology_readings_device_id_created_at_idx" ON "astrology_readings"("device_id", "created_at");

-- AddForeignKey
ALTER TABLE "astrology_readings" ADD CONSTRAINT "astrology_readings_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
