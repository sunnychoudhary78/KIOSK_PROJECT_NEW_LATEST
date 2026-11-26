-- Name + color tag for society phone entries.
ALTER TABLE "society_phones" ADD COLUMN "name" VARCHAR(120) NOT NULL DEFAULT '';
ALTER TABLE "society_phones" ADD COLUMN "color" VARCHAR(32) NOT NULL DEFAULT 'blue';

CREATE INDEX "society_phones_name_idx" ON "society_phones"("name");
