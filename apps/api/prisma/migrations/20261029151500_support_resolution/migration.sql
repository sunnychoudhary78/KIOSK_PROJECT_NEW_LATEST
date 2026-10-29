-- CreateEnum
CREATE TYPE "SupportResolution" AS ENUM ('otp_sent', 'reprinted', 'refunded', 'no_action', 'session_ready');

-- AlterTable
ALTER TABLE "support_queries" ADD COLUMN "payment_reference" VARCHAR(80),
ADD COLUMN "resolution" "SupportResolution";
