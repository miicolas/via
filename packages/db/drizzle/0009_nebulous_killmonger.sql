/*
 * Stop-times are derived from GTFS and are replaced immediately after this
 * migration. Emptying them here makes the text-to-integer dictionary encoding
 * deterministic and avoids rewriting gigabytes of obsolete derived data.
 */
TRUNCATE TABLE "transit_trip_stop_times", "transit_trips";--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" DROP CONSTRAINT "transit_trip_stop_times_trip_id_transit_trips_id_fk";--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" DROP CONSTRAINT "transit_trip_stop_times_stop_id_transit_stops_id_fk";--> statement-breakpoint
DROP INDEX "transit_trip_stop_times_trip_idx";--> statement-breakpoint
DROP INDEX "transit_trip_stop_times_stop_departure_idx";--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" DROP CONSTRAINT "transit_trip_stop_times_trip_id_stop_sequence_pk";--> statement-breakpoint
ALTER TABLE "transit_trips" DROP CONSTRAINT "transit_trips_pkey";--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" RENAME COLUMN "trip_id" TO "trip_key";--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" RENAME COLUMN "stop_id" TO "stop_key";--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" ALTER COLUMN "trip_key" TYPE integer USING "trip_key"::integer;--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" ALTER COLUMN "stop_key" TYPE integer USING "stop_key"::integer;--> statement-breakpoint
ALTER TABLE "transit_stops" ADD COLUMN "numeric_id" serial NOT NULL;--> statement-breakpoint
ALTER TABLE "transit_trips" ADD COLUMN "numeric_id" integer PRIMARY KEY NOT NULL;--> statement-breakpoint
ALTER TABLE "transit_stops" ADD CONSTRAINT "transit_stops_numeric_id_unique" UNIQUE("numeric_id");--> statement-breakpoint
ALTER TABLE "transit_trips" ADD CONSTRAINT "transit_trips_id_unique" UNIQUE("id");--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" ADD CONSTRAINT "transit_trip_stop_times_trip_key_stop_sequence_pk" PRIMARY KEY("trip_key","stop_sequence");--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" ADD CONSTRAINT "transit_trip_stop_times_trip_key_transit_trips_numeric_id_fk" FOREIGN KEY ("trip_key") REFERENCES "public"."transit_trips"("numeric_id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" ADD CONSTRAINT "transit_trip_stop_times_stop_key_transit_stops_numeric_id_fk" FOREIGN KEY ("stop_key") REFERENCES "public"."transit_stops"("numeric_id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "transit_trip_stop_times_stop_departure_idx" ON "transit_trip_stop_times" USING btree ("stop_key","departure_seconds");--> statement-breakpoint
