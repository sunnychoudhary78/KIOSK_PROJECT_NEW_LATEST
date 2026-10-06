-- CreateTable
CREATE TABLE "fuel_stations" (
    "id" UUID NOT NULL,
    "osm_id" VARCHAR(40) NOT NULL,
    "name" VARCHAR(200),
    "address" VARCHAR(400),
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "petrol" BOOLEAN NOT NULL DEFAULT false,
    "diesel" BOOLEAN NOT NULL DEFAULT false,
    "cng" BOOLEAN NOT NULL DEFAULT false,
    "ev" BOOLEAN NOT NULL DEFAULT false,
    "fuel_untyped" BOOLEAN NOT NULL DEFAULT false,
    "last_seen_at" TIMESTAMP(3) NOT NULL,
    "miss_count" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "fuel_stations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "fuel_stations_osm_id_key" ON "fuel_stations"("osm_id");

-- CreateIndex
CREATE INDEX "fuel_stations_is_active_latitude_longitude_idx" ON "fuel_stations"("is_active", "latitude", "longitude");
