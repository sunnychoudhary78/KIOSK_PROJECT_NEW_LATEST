-- AlterTable
ALTER TABLE "surveillance_segments" ADD COLUMN "recorded_on" DATE,
ADD COLUMN "started_at" TIMESTAMP(3);

-- Backfill from object_key: surveillance/{tenant}/{device}/{YYYY-MM-DD}/{HHmmss}_....mp4
UPDATE "surveillance_segments"
SET
  "recorded_on" = CASE
    WHEN "object_key" ~ '/(\d{4}-\d{2}-\d{2})/[^/]+$'
      THEN (regexp_match("object_key", '/(\d{4}-\d{2}-\d{2})/[^/]+$'))[1]::date
    ELSE ("created_at" AT TIME ZONE 'UTC')::date
  END,
  "started_at" = CASE
    WHEN "object_key" ~ '/(\d{4}-\d{2}-\d{2})/(\d{6})_[^/]+\.mp4$'
      THEN (
        (regexp_match("object_key", '/(\d{4}-\d{2}-\d{2})/(\d{6})_[^/]+\.mp4$'))[1]
        || 'T'
        || substring((regexp_match("object_key", '/(\d{4}-\d{2}-\d{2})/(\d{6})_[^/]+\.mp4$'))[2] from 1 for 2)
        || ':'
        || substring((regexp_match("object_key", '/(\d{4}-\d{2}-\d{2})/(\d{6})_[^/]+\.mp4$'))[2] from 3 for 2)
        || ':'
        || substring((regexp_match("object_key", '/(\d{4}-\d{2}-\d{2})/(\d{6})_[^/]+\.mp4$'))[2] from 5 for 2)
        || 'Z'
      )::timestamptz AT TIME ZONE 'UTC'
    WHEN "object_key" ~ '/(\d{4}-\d{2}-\d{2})/[^/]+$'
      THEN ((regexp_match("object_key", '/(\d{4}-\d{2}-\d{2})/[^/]+$'))[1] || 'T00:00:00Z')::timestamptz AT TIME ZONE 'UTC'
    ELSE "created_at"
  END;

-- AlterTable
ALTER TABLE "surveillance_segments" ALTER COLUMN "recorded_on" SET NOT NULL,
ALTER COLUMN "started_at" SET NOT NULL;

-- CreateIndex
CREATE INDEX "surveillance_segments_device_id_recorded_on_started_at_idx" ON "surveillance_segments"("device_id", "recorded_on", "started_at");
