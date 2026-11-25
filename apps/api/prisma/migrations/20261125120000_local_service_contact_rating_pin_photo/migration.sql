-- AlterTable
ALTER TABLE "local_service_contacts" ADD COLUMN "rating" DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE "local_service_contacts" ADD COLUMN "pinned" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "local_service_contacts" ADD COLUMN "address" TEXT;
ALTER TABLE "local_service_contacts" ADD COLUMN "photo_storage_path" TEXT;

-- CreateIndex
CREATE INDEX "local_service_contacts_category_id_pinned_rating_idx" ON "local_service_contacts"("category_id", "pinned", "rating");
