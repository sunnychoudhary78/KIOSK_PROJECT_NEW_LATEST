-- Demo enrichment so kiosk Find Services shows pinned → nearest → rating clearly.
-- Kiosk origin used below: 28.6060, 77.4300 (Gaur City / Greater Noida area).

-- Appliance repair (category a…001)
UPDATE "local_service_contacts" SET
  "pinned" = true,
  "rating" = 4.0,
  "address" = 'Shop 14, Gaur City 2 Market',
  "latitude" = 28.6285,
  "longitude" = 77.4300
WHERE "id" = 'c0000000-0000-4000-8000-000000000005'; -- Singla RO Mark ~2.5 km, PINNED

UPDATE "local_service_contacts" SET
  "pinned" = true,
  "rating" = 3.5,
  "address" = 'Near Hajipur Crossing',
  "latitude" = 28.6400,
  "longitude" = 77.4300
WHERE "id" = 'c0000000-0000-4000-8000-000000000006'; -- Hare Ram ~3.8 km, PINNED

UPDATE "local_service_contacts" SET
  "pinned" = false,
  "rating" = 3.0,
  "address" = 'Gaur City 1, Tower 5 area',
  "latitude" = 28.6090,
  "longitude" = 77.4300
WHERE "id" = 'c0000000-0000-4000-8000-000000000001'; -- Parvesh ~0.3 km (nearest)

UPDATE "local_service_contacts" SET
  "pinned" = false,
  "rating" = 4.8,
  "address" = 'Sector 16C, Noida Extension',
  "latitude" = 28.6140,
  "longitude" = 77.4300
WHERE "id" = 'c0000000-0000-4000-8000-000000000003'; -- Mr. Repair ~0.9 km

UPDATE "local_service_contacts" SET
  "pinned" = false,
  "rating" = 4.9,
  "address" = 'Main Market, Chiranjiv Vihar',
  "latitude" = 28.6195,
  "longitude" = 77.4300
WHERE "id" = 'c0000000-0000-4000-8000-000000000004'; -- Repair 24 ~1.5 km, top rating

UPDATE "local_service_contacts" SET
  "pinned" = false,
  "rating" = 4.2,
  "address" = 'Opp. Gaur City Mall',
  "latitude" = 28.6220,
  "longitude" = 77.4320
WHERE "id" = 'c0000000-0000-4000-8000-000000000002'; -- Sachin ~1.8 km

UPDATE "local_service_contacts" SET
  "pinned" = false,
  "rating" = 2.5,
  "address" = 'Bisrakh Road workshop',
  "latitude" = 28.6350,
  "longitude" = 77.4300
WHERE "id" = 'c0000000-0000-4000-8000-000000000007'; -- Universal ~3.2 km

-- Sample enrichment for plumber + electrician so other categories look filled too
UPDATE "local_service_contacts" SET
  "pinned" = true, "rating" = 4.7, "address" = 'Gaur City 2 plumbing hub',
  "latitude" = 28.6105, "longitude" = 77.4285
WHERE "id" = 'c0000000-0000-4000-8000-000000000110';

UPDATE "local_service_contacts" SET
  "pinned" = false, "rating" = 4.5, "address" = 'Sector 4, Greater Noida West',
  "latitude" = 28.6120, "longitude" = 77.4310
WHERE "id" = 'c0000000-0000-4000-8000-000000000111';

UPDATE "local_service_contacts" SET
  "pinned" = false, "rating" = 3.8, "address" = 'Near City Park',
  "latitude" = 28.6180, "longitude" = 77.4290
WHERE "id" = 'c0000000-0000-4000-8000-000000000112';

UPDATE "local_service_contacts" SET
  "pinned" = true, "rating" = 4.6, "address" = 'Electrical mart, GC-2',
  "latitude" = 28.6110, "longitude" = 77.4295
WHERE "id" = 'c0000000-0000-4000-8000-000000000056';

UPDATE "local_service_contacts" SET
  "pinned" = false, "rating" = 4.3, "address" = 'Tower circle shop',
  "latitude" = 28.6075, "longitude" = 77.4305
WHERE "id" = 'c0000000-0000-4000-8000-000000000057';

UPDATE "local_service_contacts" SET
  "pinned" = false, "rating" = 3.9, "address" = 'Hajipur service lane',
  "latitude" = 28.6200, "longitude" = 77.4280
WHERE "id" = 'c0000000-0000-4000-8000-000000000058';

-- Place every active kiosk near the demo cluster so distance chips appear
UPDATE "devices"
SET
  "latitude" = 28.6060,
  "longitude" = 77.4300,
  "address" = COALESCE(NULLIF(TRIM("address"), ''), 'Gaur City 2, Greater Noida West')
WHERE "status" = 'active'
  AND ("latitude" IS NULL OR "longitude" IS NULL);
