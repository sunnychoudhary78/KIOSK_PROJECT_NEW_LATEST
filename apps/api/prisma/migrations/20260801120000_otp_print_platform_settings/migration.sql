-- AlterTable
ALTER TABLE "users" ALTER COLUMN "password_hash" DROP NOT NULL;

-- CreateTable
CREATE TABLE "platform_settings" (
    "id" UUID NOT NULL,
    "setting_key" VARCHAR(100) NOT NULL,
    "setting_value" JSONB NOT NULL,
    "description" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "platform_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "phone_otp_sessions" (
    "id" UUID NOT NULL,
    "phone" TEXT NOT NULL,
    "code_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "phone_otp_sessions_pkey" PRIMARY KEY ("id")
);

-- AlterTable
ALTER TABLE "otp_challenges" ADD COLUMN "attempt_count" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "otp_documents" (
    "id" UUID NOT NULL,
    "challenge_id" UUID NOT NULL,
    "file_name" TEXT NOT NULL,
    "storage_path" TEXT NOT NULL,
    "content_type" TEXT NOT NULL DEFAULT 'application/pdf',
    "page_count" INTEGER NOT NULL DEFAULT 1,
    "byte_size" INTEGER NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_documents_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "platform_settings_setting_key_key" ON "platform_settings"("setting_key");

-- CreateIndex
CREATE UNIQUE INDEX "phone_otp_sessions_phone_key" ON "phone_otp_sessions"("phone");

-- CreateIndex
CREATE INDEX "phone_otp_sessions_expires_at_idx" ON "phone_otp_sessions"("expires_at");

-- CreateIndex
CREATE INDEX "otp_documents_challenge_id_idx" ON "otp_documents"("challenge_id");

-- AddForeignKey
ALTER TABLE "otp_documents" ADD CONSTRAINT "otp_documents_challenge_id_fkey" FOREIGN KEY ("challenge_id") REFERENCES "otp_challenges"("id") ON DELETE CASCADE ON UPDATE CASCADE;
