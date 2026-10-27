ALTER TABLE "support_queries" ALTER COLUMN "payment_id" DROP NOT NULL;
ALTER TABLE "support_queries" ALTER COLUMN "user_id" DROP NOT NULL;

ALTER TABLE "support_queries" ADD COLUMN "print_job_id" UUID;

CREATE UNIQUE INDEX "support_queries_print_job_id_key" ON "support_queries"("print_job_id");

ALTER TABLE "support_queries" ADD CONSTRAINT "support_queries_print_job_id_fkey" FOREIGN KEY ("print_job_id") REFERENCES "print_jobs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
