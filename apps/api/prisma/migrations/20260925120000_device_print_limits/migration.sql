-- AlterTable
ALTER TABLE "devices" ADD COLUMN "max_pages_per_session" INTEGER NOT NULL DEFAULT 10;
ALTER TABLE "devices" ADD COLUMN "free_pages_per_session" INTEGER NOT NULL DEFAULT 5;
ALTER TABLE "devices" ADD COLUMN "extra_page_charge_rupees" INTEGER NOT NULL DEFAULT 10;
ALTER TABLE "devices" ADD COLUMN "free_color_pages_per_session" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "devices" ADD COLUMN "extra_color_page_charge_rupees" INTEGER NOT NULL DEFAULT 20;

-- Copy current global otp_print_config values onto every kiosk.
UPDATE "devices" AS d
SET
  "max_pages_per_session" = COALESCE((s.setting_value->>'maxPagesPerSession')::int, 10),
  "free_pages_per_session" = COALESCE((s.setting_value->>'freePagesPerSession')::int, 5),
  "extra_page_charge_rupees" = COALESCE((s.setting_value->>'extraPageChargeRupees')::int, 10),
  "free_color_pages_per_session" = COALESCE((s.setting_value->>'freeColorPagesPerSession')::int, 0),
  "extra_color_page_charge_rupees" = COALESCE((s.setting_value->>'extraColorPageChargeRupees')::int, 20)
FROM "platform_settings" AS s
WHERE s.setting_key = 'otp_print_config';
