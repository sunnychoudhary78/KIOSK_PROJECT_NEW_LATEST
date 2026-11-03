-- AlterTable
ALTER TABLE "payments" ADD COLUMN "razorpay_qr_code_id" TEXT,
ADD COLUMN "qr_image_url" VARCHAR(500);

-- CreateIndex
CREATE UNIQUE INDEX "payments_razorpay_qr_code_id_key" ON "payments"("razorpay_qr_code_id");
