-- AlterTable
ALTER TABLE "support_queries" ADD COLUMN "device_id" UUID;
ALTER TABLE "support_queries" ADD COLUMN "category" VARCHAR(40);

-- CreateIndex
CREATE INDEX "support_queries_device_id_created_at_idx" ON "support_queries"("device_id", "created_at");

-- AddForeignKey
ALTER TABLE "support_queries" ADD CONSTRAINT "support_queries_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE CASCADE ON UPDATE CASCADE;
