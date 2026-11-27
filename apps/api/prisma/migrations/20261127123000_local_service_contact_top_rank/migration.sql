-- Replace boolean pin with ordered Top 5 slots (1–5) per category.
ALTER TABLE "local_service_contacts" ADD COLUMN "top_rank" INTEGER;

-- Keep previously pinned contacts featured (stable order by rating, then name).
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY "category_id"
      ORDER BY "rating" DESC, "name" ASC, id ASC
    ) AS rn
  FROM "local_service_contacts"
  WHERE "pinned" = true
)
UPDATE "local_service_contacts" AS c
SET "top_rank" = ranked.rn
FROM ranked
WHERE c.id = ranked.id
  AND ranked.rn <= 5;

ALTER TABLE "local_service_contacts" DROP COLUMN "pinned";

DROP INDEX IF EXISTS "local_service_contacts_category_id_pinned_rating_idx";

CREATE INDEX "local_service_contacts_category_id_top_rank_rating_idx"
  ON "local_service_contacts"("category_id", "top_rank", "rating");

-- Only one contact per category may occupy each Top 5 slot.
CREATE UNIQUE INDEX "local_service_contacts_category_id_top_rank_key"
  ON "local_service_contacts"("category_id", "top_rank")
  WHERE "top_rank" IS NOT NULL;
