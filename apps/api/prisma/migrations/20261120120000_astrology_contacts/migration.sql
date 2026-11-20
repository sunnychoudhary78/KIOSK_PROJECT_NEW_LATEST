-- CreateEnum
CREATE TYPE "AstrologyContactKind" AS ENUM ('astrologer', 'pandit');

-- CreateTable
CREATE TABLE "astrology_contacts" (
    "id" UUID NOT NULL,
    "kind" "AstrologyContactKind" NOT NULL,
    "name" TEXT NOT NULL,
    "phone" VARCHAR(10) NOT NULL,
    "rating" DECIMAL(2,1) NOT NULL,
    "sort_order" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "astrology_contacts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "astrology_contacts_kind_sort_order_idx" ON "astrology_contacts"("kind", "sort_order");
