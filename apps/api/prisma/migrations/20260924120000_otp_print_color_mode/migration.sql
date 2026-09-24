-- CreateEnum
CREATE TYPE "PrintColorMode" AS ENUM ('bw', 'color');

-- AlterTable
ALTER TABLE "otp_challenges" ADD COLUMN "print_color_mode" "PrintColorMode" NOT NULL DEFAULT 'bw';

-- AlterTable
ALTER TABLE "payments" ADD COLUMN "print_color_mode" "PrintColorMode" NOT NULL DEFAULT 'bw';

-- AlterTable
ALTER TABLE "print_jobs" ADD COLUMN "print_color_mode" "PrintColorMode" NOT NULL DEFAULT 'bw';
