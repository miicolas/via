CREATE TABLE "station_hour_profiles" (
	"stop_id" text NOT NULL,
	"day_type" text NOT NULL,
	"hour" integer NOT NULL,
	"share" real NOT NULL,
	"peak_ratio" real NOT NULL,
	"source" text NOT NULL,
	"source_updated_at" timestamp with time zone NOT NULL,
	"imported_at" timestamp with time zone NOT NULL,
	CONSTRAINT "station_hour_profiles_stop_id_day_type_hour_pk" PRIMARY KEY("stop_id","day_type","hour")
);
--> statement-breakpoint
ALTER TABLE "station_hour_profiles" ADD CONSTRAINT "station_hour_profiles_stop_id_transit_stops_id_fk" FOREIGN KEY ("stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "station_hour_profiles_day_hour_idx" ON "station_hour_profiles" USING btree ("day_type","hour");