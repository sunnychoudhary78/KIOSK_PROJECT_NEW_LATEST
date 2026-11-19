-- Per-document / job copy count for Quick Print, OTP Print, and DigiLocker.
ALTER TABLE "otp_documents" ADD COLUMN "copies" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "quick_print_documents" ADD COLUMN "copies" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "print_jobs" ADD COLUMN "copies" INTEGER NOT NULL DEFAULT 1;
