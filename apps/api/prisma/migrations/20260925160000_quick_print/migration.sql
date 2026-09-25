-- CreateEnum
CREATE TYPE "QuickPrintSessionStatus" AS ENUM ('waiting_upload', 'awaiting_payment', 'ready', 'consumed', 'expired', 'cancelled');

-- AlterEnum
ALTER TYPE "PrintJobSource" ADD VALUE 'quick_print';

-- CreateTable
CREATE TABLE "quick_print_sessions" (
    "id" UUID NOT NULL,
    "device_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "status" "QuickPrintSessionStatus" NOT NULL DEFAULT 'waiting_upload',
    "document_label" TEXT NOT NULL DEFAULT '',
    "page_count" INTEGER NOT NULL DEFAULT 0,
    "print_color_mode" "PrintColorMode" NOT NULL DEFAULT 'bw',
    "expires_at" TIMESTAMP(3) NOT NULL,
    "print_job_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "quick_print_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quick_print_documents" (
    "id" UUID NOT NULL,
    "session_id" UUID NOT NULL,
    "file_name" TEXT NOT NULL,
    "storage_path" TEXT NOT NULL,
    "content_type" TEXT NOT NULL DEFAULT 'application/pdf',
    "page_count" INTEGER NOT NULL DEFAULT 1,
    "byte_size" INTEGER NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "quick_print_documents_pkey" PRIMARY KEY ("id")
);

-- AlterTable
ALTER TABLE "payments" ALTER COLUMN "challenge_id" DROP NOT NULL;
ALTER TABLE "payments" ALTER COLUMN "user_id" DROP NOT NULL;
ALTER TABLE "payments" ADD COLUMN "quick_print_session_id" UUID;

-- CreateIndex
CREATE UNIQUE INDEX "quick_print_sessions_token_hash_key" ON "quick_print_sessions"("token_hash");

-- CreateIndex
CREATE UNIQUE INDEX "quick_print_sessions_print_job_id_key" ON "quick_print_sessions"("print_job_id");

-- CreateIndex
CREATE INDEX "quick_print_sessions_device_id_status_idx" ON "quick_print_sessions"("device_id", "status");

-- CreateIndex
CREATE INDEX "quick_print_sessions_status_expires_at_idx" ON "quick_print_sessions"("status", "expires_at");

-- CreateIndex
CREATE INDEX "quick_print_documents_session_id_idx" ON "quick_print_documents"("session_id");

-- CreateIndex
CREATE UNIQUE INDEX "payments_quick_print_session_id_key" ON "payments"("quick_print_session_id");

-- AddForeignKey
ALTER TABLE "quick_print_sessions" ADD CONSTRAINT "quick_print_sessions_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quick_print_sessions" ADD CONSTRAINT "quick_print_sessions_print_job_id_fkey" FOREIGN KEY ("print_job_id") REFERENCES "print_jobs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quick_print_documents" ADD CONSTRAINT "quick_print_documents_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "quick_print_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_quick_print_session_id_fkey" FOREIGN KEY ("quick_print_session_id") REFERENCES "quick_print_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
