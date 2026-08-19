/* The timetable is derived data, re-imported right after this migration runs;
 * emptying trips lets profile_key/start_seconds arrive NOT NULL without a fake
 * default (same precedent as 0009). */
TRUNCATE TABLE "transit_trip_stop_times", "transit_trips";--> statement-breakpoint
CREATE TABLE "transit_profile_stops" (
	"profile_key" integer NOT NULL,
	"position" integer NOT NULL,
	"stop_key" integer NOT NULL,
	"arrival_offset" integer NOT NULL,
	"departure_offset" integer NOT NULL,
	CONSTRAINT "transit_profile_stops_profile_key_position_pk" PRIMARY KEY("profile_key","position")
);
--> statement-breakpoint
CREATE TABLE "transit_time_profiles" (
	"id" integer PRIMARY KEY NOT NULL
);
--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" DISABLE ROW LEVEL SECURITY;--> statement-breakpoint
DROP TABLE "transit_trip_stop_times" CASCADE;--> statement-breakpoint
ALTER TABLE "transit_trips" ADD COLUMN "profile_key" integer NOT NULL;--> statement-breakpoint
ALTER TABLE "transit_trips" ADD COLUMN "start_seconds" integer NOT NULL;--> statement-breakpoint
ALTER TABLE "transit_profile_stops" ADD CONSTRAINT "transit_profile_stops_profile_key_transit_time_profiles_id_fk" FOREIGN KEY ("profile_key") REFERENCES "public"."transit_time_profiles"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_profile_stops" ADD CONSTRAINT "transit_profile_stops_stop_key_transit_stops_numeric_id_fk" FOREIGN KEY ("stop_key") REFERENCES "public"."transit_stops"("numeric_id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "transit_profile_stops_stop_idx" ON "transit_profile_stops" USING btree ("stop_key");--> statement-breakpoint
ALTER TABLE "transit_trips" ADD CONSTRAINT "transit_trips_profile_key_transit_time_profiles_id_fk" FOREIGN KEY ("profile_key") REFERENCES "public"."transit_time_profiles"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "transit_trips_profile_idx" ON "transit_trips" USING btree ("profile_key");