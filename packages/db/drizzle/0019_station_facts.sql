-- station_accessibility becomes station_facts: one row per fact known about a
-- station, keyed (stop_id, kind). The IDFM level codes are translated into
-- Via's own `condition` vocabulary here so existing rows survive the rename;
-- the importer writes `condition` directly from now on. Provenance moves onto
-- the row (source, source_ref, source_updated_at, imported_at), which retires
-- the accessibility:* keys in import_meta.
ALTER TABLE "station_accessibility" RENAME TO "station_facts";--> statement-breakpoint
ALTER TABLE "station_facts" RENAME COLUMN "source_stop_point_id" TO "source_ref";--> statement-breakpoint
ALTER TABLE "station_facts" RENAME COLUMN "comment" TO "detail";--> statement-breakpoint
ALTER TABLE "station_facts" RENAME CONSTRAINT "station_accessibility_stop_id_transit_stops_id_fk" TO "station_facts_stop_id_transit_stops_id_fk";--> statement-breakpoint
ALTER TABLE "station_facts" ADD COLUMN "kind" text NOT NULL DEFAULT 'accessibility';--> statement-breakpoint
ALTER TABLE "station_facts" ALTER COLUMN "kind" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "station_facts" ADD COLUMN "condition" text;--> statement-breakpoint
ALTER TABLE "station_facts" ADD COLUMN "source" text NOT NULL DEFAULT 'idfm:acces-gare';--> statement-breakpoint
ALTER TABLE "station_facts" ALTER COLUMN "source" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "station_facts" ADD COLUMN "source_updated_at" timestamp with time zone;--> statement-breakpoint
UPDATE "station_facts" SET "condition" = CASE "level_id"
  WHEN 3 THEN 'reservationRequired'
  WHEN 4 THEN 'staffAssistance'
  WHEN 6 THEN 'autonomous'
END;--> statement-breakpoint
-- Unknown levels were already invisible: readers translated them to nothing.
DELETE FROM "station_facts" WHERE "condition" IS NULL;--> statement-breakpoint
UPDATE "station_facts" SET "source_updated_at" =
  (SELECT "value"::timestamptz FROM "import_meta" WHERE "key" = 'accessibility:source-updated-at');--> statement-breakpoint
ALTER TABLE "station_facts" ALTER COLUMN "condition" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "station_facts" ADD CONSTRAINT "station_facts_condition_check" CHECK ("condition" IN ('autonomous', 'staffAssistance', 'reservationRequired'));--> statement-breakpoint
ALTER TABLE "station_facts" DROP CONSTRAINT "station_accessibility_pkey";--> statement-breakpoint
ALTER TABLE "station_facts" ADD CONSTRAINT "station_facts_stop_id_kind_pk" PRIMARY KEY ("stop_id", "kind");--> statement-breakpoint
ALTER TABLE "station_facts" DROP CONSTRAINT "station_accessibility_source_stop_point_id_unique";--> statement-breakpoint
CREATE UNIQUE INDEX "station_facts_kind_source_ref_uidx" ON "station_facts" USING btree ("kind", "source_ref");--> statement-breakpoint
DROP INDEX "station_accessibility_level_idx";--> statement-breakpoint
ALTER TABLE "station_facts" DROP COLUMN "level_id";--> statement-breakpoint
ALTER TABLE "station_facts" DROP COLUMN "level_name";--> statement-breakpoint
-- Provenance now lives on the rows; import_meta goes back to GTFS bookkeeping.
DELETE FROM "import_meta" WHERE "key" IN ('accessibility:imported-at', 'accessibility:source-updated-at');--> statement-breakpoint
-- Favorite stations have one home, account_favorite_stations. Nothing ever
-- wrote a 'favorite' place, so this deletes zero rows; the check keeps it so.
DELETE FROM "account_places" WHERE "role" = 'favorite';--> statement-breakpoint
ALTER TABLE "account_places" ADD CONSTRAINT "account_places_role_check" CHECK ("role" IN ('home', 'work'));--> statement-breakpoint
-- Backfill the prefixed Navitia spellings so canonicalStationIDs() can drop
-- its regexes before the next GTFS import rebuilds the alias table.
INSERT INTO "transit_stop_aliases" ("source_id", "stop_id")
  SELECT 'stop_point:' || "source_id", "stop_id" FROM "transit_stop_aliases"
  WHERE "source_id" NOT LIKE 'stop\_point:%' AND "source_id" NOT LIKE 'stop\_area:%'
  ON CONFLICT DO NOTHING;--> statement-breakpoint
INSERT INTO "transit_stop_aliases" ("source_id", "stop_id")
  SELECT DISTINCT 'stop_area:' || "stop_id", "stop_id" FROM "transit_stop_aliases"
  ON CONFLICT DO NOTHING;
