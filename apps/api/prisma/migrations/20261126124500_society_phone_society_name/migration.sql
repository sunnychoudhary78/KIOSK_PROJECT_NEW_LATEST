-- Society / building name for society phone entries.
ALTER TABLE "society_phones" ADD COLUMN "society_name" VARCHAR(160) NOT NULL DEFAULT '';

CREATE INDEX "society_phones_society_name_idx" ON "society_phones"("society_name");
