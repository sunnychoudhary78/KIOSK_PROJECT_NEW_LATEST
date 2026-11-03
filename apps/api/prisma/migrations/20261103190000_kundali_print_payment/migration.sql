-- AlterTable
ALTER TABLE "devices" ADD COLUMN "kundali_color_print_charge_rupees" INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "payments" ADD COLUMN "print_job_id" UUID,
ADD COLUMN "checkout_token" VARCHAR(64);

-- CreateIndex
CREATE UNIQUE INDEX "payments_print_job_id_key" ON "payments"("print_job_id");

-- CreateIndex
CREATE UNIQUE INDEX "payments_checkout_token_key" ON "payments"("checkout_token");

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_print_job_id_fkey" FOREIGN KEY ("print_job_id") REFERENCES "print_jobs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
