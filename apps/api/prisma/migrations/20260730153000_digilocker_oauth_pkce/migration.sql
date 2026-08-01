-- AlterTable
ALTER TABLE "digilocker_sessions" ADD COLUMN "state" TEXT,
ADD COLUMN "code_verifier" TEXT,
ADD COLUMN "access_token" TEXT,
ADD COLUMN "id_token" TEXT,
ADD COLUMN "token_expires_at" TIMESTAMP(3),
ADD COLUMN "consent_valid_till" TEXT;

-- Existing sandbox rows cannot satisfy new required columns; clear sessions before enforcing NOT NULL.
DELETE FROM "print_jobs" WHERE "digilocker_session_id" IS NOT NULL;
DELETE FROM "digilocker_sessions";

ALTER TABLE "digilocker_sessions" ALTER COLUMN "state" SET NOT NULL;
ALTER TABLE "digilocker_sessions" ALTER COLUMN "code_verifier" SET NOT NULL;

CREATE UNIQUE INDEX "digilocker_sessions_state_key" ON "digilocker_sessions"("state");

-- AlterTable
ALTER TABLE "print_jobs" ADD COLUMN "payload_path" TEXT;
