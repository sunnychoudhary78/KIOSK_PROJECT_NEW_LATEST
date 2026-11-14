-- AlterTable
ALTER TABLE "devices" ADD COLUMN "shutter_command" VARCHAR(8);
ALTER TABLE "devices" ADD COLUMN "shutter_command_requested_at" TIMESTAMP(3);
