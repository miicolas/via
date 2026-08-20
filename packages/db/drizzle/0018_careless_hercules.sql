CREATE TABLE "station_accessibility" (
	"stop_id" text PRIMARY KEY NOT NULL,
	"source_stop_point_id" text NOT NULL,
	"level_id" integer NOT NULL,
	"level_name" text NOT NULL,
	"comment" text,
	"imported_at" timestamp with time zone NOT NULL,
	CONSTRAINT "station_accessibility_source_stop_point_id_unique" UNIQUE("source_stop_point_id")
);
--> statement-breakpoint
CREATE TABLE "transit_stop_aliases" (
	"source_id" text PRIMARY KEY NOT NULL,
	"stop_id" text NOT NULL
);
--> statement-breakpoint
ALTER TABLE "station_accessibility" ADD CONSTRAINT "station_accessibility_stop_id_transit_stops_id_fk" FOREIGN KEY ("stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_stop_aliases" ADD CONSTRAINT "transit_stop_aliases_stop_id_transit_stops_id_fk" FOREIGN KEY ("stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "station_accessibility_level_idx" ON "station_accessibility" USING btree ("level_id");--> statement-breakpoint
CREATE INDEX "transit_stop_aliases_stop_idx" ON "transit_stop_aliases" USING btree ("stop_id");