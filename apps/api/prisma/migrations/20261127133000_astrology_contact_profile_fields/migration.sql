-- Optional profile details shown on kiosk astrology contact cards.
ALTER TABLE "astrology_contacts" ADD COLUMN "address" VARCHAR(240);
ALTER TABLE "astrology_contacts" ADD COLUMN "degree" VARCHAR(120);
ALTER TABLE "astrology_contacts" ADD COLUMN "experience_years" INTEGER;
