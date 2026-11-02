-- Society phone allowlist for a separate free-print quota.
CREATE TABLE "society_phones" (
    "id" UUID NOT NULL,
    "phone" VARCHAR(20) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "society_phones_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "society_phones_phone_key" ON "society_phones"("phone");
