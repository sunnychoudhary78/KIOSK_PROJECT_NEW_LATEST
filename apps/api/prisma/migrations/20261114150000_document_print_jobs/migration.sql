-- AlterTable
ALTER TABLE "otp_documents" ADD COLUMN "print_job_id" UUID;

-- AlterTable
ALTER TABLE "quick_print_documents" ADD COLUMN "print_job_id" UUID;

-- CreateIndex
CREATE UNIQUE INDEX "otp_documents_print_job_id_key" ON "otp_documents"("print_job_id");

-- CreateIndex
CREATE UNIQUE INDEX "quick_print_documents_print_job_id_key" ON "quick_print_documents"("print_job_id");

-- AddForeignKey
ALTER TABLE "otp_documents" ADD CONSTRAINT "otp_documents_print_job_id_fkey" FOREIGN KEY ("print_job_id") REFERENCES "print_jobs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quick_print_documents" ADD CONSTRAINT "quick_print_documents_print_job_id_fkey" FOREIGN KEY ("print_job_id") REFERENCES "print_jobs"("id") ON DELETE SET NULL ON UPDATE CASCADE;
