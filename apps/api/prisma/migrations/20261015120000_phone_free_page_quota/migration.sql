-- CreateEnum
CREATE TYPE "FreePageLedgerStatus" AS ENUM ('reserved', 'consumed', 'released');

-- AlterTable devices: free-disabled night window (Asia/Kolkata local HH:mm)
ALTER TABLE "devices" ADD COLUMN "free_disabled_from_local" VARCHAR(5);
ALTER TABLE "devices" ADD COLUMN "free_disabled_to_local" VARCHAR(5);

-- AlterTable otp_challenges
ALTER TABLE "otp_challenges" ADD COLUMN "free_pages_granted" INTEGER NOT NULL DEFAULT 0;

-- AlterTable quick_print_sessions
ALTER TABLE "quick_print_sessions" ADD COLUMN "free_pages_granted" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "quick_print_sessions" ADD COLUMN "verified_phone" TEXT;
ALTER TABLE "quick_print_sessions" ADD COLUMN "phone_verified_at" TIMESTAMP(3);

-- AlterTable print_jobs
ALTER TABLE "print_jobs" ADD COLUMN "free_pages_granted" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "phone_free_page_ledger" (
    "id" UUID NOT NULL,
    "phone" VARCHAR(20) NOT NULL,
    "print_color_mode" "PrintColorMode" NOT NULL,
    "pages" INTEGER NOT NULL,
    "status" "FreePageLedgerStatus" NOT NULL DEFAULT 'reserved',
    "period_key" VARCHAR(16) NOT NULL,
    "otp_challenge_id" UUID,
    "quick_print_session_id" UUID,
    "print_job_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "phone_free_page_ledger_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "phone_free_page_ledger_otp_challenge_id_key" ON "phone_free_page_ledger"("otp_challenge_id");
CREATE UNIQUE INDEX "phone_free_page_ledger_quick_print_session_id_key" ON "phone_free_page_ledger"("quick_print_session_id");
CREATE UNIQUE INDEX "phone_free_page_ledger_print_job_id_key" ON "phone_free_page_ledger"("print_job_id");
CREATE INDEX "phone_free_page_ledger_phone_status_print_color_mode_idx" ON "phone_free_page_ledger"("phone", "status", "print_color_mode");
CREATE INDEX "phone_free_page_ledger_phone_period_key_print_color_mode_idx" ON "phone_free_page_ledger"("phone", "period_key", "print_color_mode");

ALTER TABLE "phone_free_page_ledger" ADD CONSTRAINT "phone_free_page_ledger_otp_challenge_id_fkey" FOREIGN KEY ("otp_challenge_id") REFERENCES "otp_challenges"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "phone_free_page_ledger" ADD CONSTRAINT "phone_free_page_ledger_quick_print_session_id_fkey" FOREIGN KEY ("quick_print_session_id") REFERENCES "quick_print_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "phone_free_page_ledger" ADD CONSTRAINT "phone_free_page_ledger_print_job_id_fkey" FOREIGN KEY ("print_job_id") REFERENCES "print_jobs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Seed platform setting for global free quota (idempotent)
INSERT INTO "platform_settings" ("id", "setting_key", "setting_value", "description", "is_active", "created_at", "updated_at")
SELECT gen_random_uuid(), 'print_free_quota_config', '{"period":"daily","freeBwPages":5,"freeColorPages":0}'::jsonb, 'Global per-phone free print page quota', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
WHERE NOT EXISTS (
  SELECT 1 FROM "platform_settings" WHERE "setting_key" = 'print_free_quota_config'
);
