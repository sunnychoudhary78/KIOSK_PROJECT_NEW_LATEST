-- Fleet-wide service availability for admin "Out of Service" / "Under Maintenance".
CREATE TYPE "service_operational_status" AS ENUM ('available', 'under_maintenance', 'out_of_service');

ALTER TABLE "platform_services"
  ADD COLUMN IF NOT EXISTS "operational_status" "service_operational_status" NOT NULL DEFAULT 'available';
