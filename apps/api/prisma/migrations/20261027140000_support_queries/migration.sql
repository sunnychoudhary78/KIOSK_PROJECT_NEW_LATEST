-- CreateEnum
CREATE TYPE "SupportQueryStatus" AS ENUM ('open', 'resolved');

-- CreateTable
CREATE TABLE "support_queries" (
    "id" UUID NOT NULL,
    "payment_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "phone" TEXT NOT NULL DEFAULT '',
    "message" VARCHAR(500) NOT NULL,
    "status" "SupportQueryStatus" NOT NULL DEFAULT 'open',
    "razorpay_order_id" TEXT,
    "amount_paise" INTEGER NOT NULL,
    "failure_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMP(3),

    CONSTRAINT "support_queries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "support_queries_payment_id_key" ON "support_queries"("payment_id");

-- CreateIndex
CREATE INDEX "support_queries_status_created_at_idx" ON "support_queries"("status", "created_at");

-- AddForeignKey
ALTER TABLE "support_queries" ADD CONSTRAINT "support_queries_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "payments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_queries" ADD CONSTRAINT "support_queries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
