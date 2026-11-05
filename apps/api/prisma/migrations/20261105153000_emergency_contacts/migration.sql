-- Global emergency / SOS helplines shown on the kiosk (Lucknow NIC seed).

CREATE TABLE "emergency_contacts" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "phone" VARCHAR(32) NOT NULL,
    "icon" VARCHAR(32) NOT NULL,
    "sort_order" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "emergency_contacts_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "emergency_contacts_sort_order_idx" ON "emergency_contacts"("sort_order");

INSERT INTO "emergency_contacts" ("id", "name", "phone", "icon", "sort_order", "created_at", "updated_at") VALUES
('e0000000-0000-4000-8000-000000000001', 'Police', '112', 'police', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('e0000000-0000-4000-8000-000000000002', 'Fire', '101', 'fire', 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('e0000000-0000-4000-8000-000000000003', 'Ambulance', '102', 'ambulance', 3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('e0000000-0000-4000-8000-000000000004', 'Ambulance (108)', '108', 'ambulance', 4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('e0000000-0000-4000-8000-000000000005', 'Women Helpline', '1090', 'women', 5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('e0000000-0000-4000-8000-000000000006', 'Citizen Call Center', '155300', 'phone', 6, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('e0000000-0000-4000-8000-000000000007', 'Child Helpline', '1098', 'child', 7, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('e0000000-0000-4000-8000-000000000008', 'Chief Minister Helpline', '1076', 'sos', 8, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('e0000000-0000-4000-8000-000000000009', 'UP Women Commission Helpline', '1800-180-5220', 'women', 9, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('e0000000-0000-4000-8000-00000000000a', 'DDMA Emergency Operations Center', '1077', 'disaster', 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
