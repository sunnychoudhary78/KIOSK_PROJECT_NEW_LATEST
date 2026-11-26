-- Recreate enum so numerology can be added inside Prisma's migration transaction.
-- Demo numerology contacts are seeded only in local/dev (prisma/seed.ts).

CREATE TYPE "AstrologyContactKind_new" AS ENUM ('astrologer', 'pandit', 'numerology');

ALTER TABLE "astrology_contacts"
  ALTER COLUMN "kind" TYPE "AstrologyContactKind_new"
  USING ("kind"::text::"AstrologyContactKind_new");

DROP TYPE "AstrologyContactKind";

ALTER TYPE "AstrologyContactKind_new" RENAME TO "AstrologyContactKind";
