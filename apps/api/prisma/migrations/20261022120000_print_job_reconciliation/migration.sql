-- CreateEnum
CREATE TYPE "PrintJobReconcileStatus" AS ENUM (
  'pending',
  'verified',
  'partial',
  'reconciliation_required',
  'unknown'
);

-- AlterTable devices
ALTER TABLE "devices" ADD COLUMN "printer_health" JSONB;
ALTER TABLE "devices" ADD COLUMN "printer_health_at" TIMESTAMP(3);

-- AlterTable print_jobs
ALTER TABLE "print_jobs" ADD COLUMN "pages_expected" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "print_jobs" ADD COLUMN "pages_reported" INTEGER;
ALTER TABLE "print_jobs" ADD COLUMN "spooler_job_id" TEXT;
ALTER TABLE "print_jobs" ADD COLUMN "page_counter_before" INTEGER;
ALTER TABLE "print_jobs" ADD COLUMN "page_counter_after" INTEGER;
ALTER TABLE "print_jobs" ADD COLUMN "reconcile_status" "PrintJobReconcileStatus" NOT NULL DEFAULT 'pending';
ALTER TABLE "print_jobs" ADD COLUMN "needs_admin_review" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "print_jobs" ADD COLUMN "reconcile_detail" TEXT;
ALTER TABLE "print_jobs" ADD COLUMN "reconciled_at" TIMESTAMP(3);

-- Backfill pages_expected from existing page_count
UPDATE "print_jobs" SET "pages_expected" = "page_count";

-- CreateIndex
CREATE INDEX "print_jobs_needs_admin_review_created_at_idx" ON "print_jobs"("needs_admin_review", "created_at");
