-- Pages credited at the last tray load, and the USB lifetime total at that moment.
ALTER TABLE "devices" ADD COLUMN "tray_pages" INTEGER;
ALTER TABLE "devices" ADD COLUMN "tray_baseline_pages" INTEGER;
