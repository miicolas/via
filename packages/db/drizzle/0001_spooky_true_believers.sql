CREATE TABLE "transit_route_pattern_stops" (
	"pattern_id" text NOT NULL,
	"stop_id" text NOT NULL,
	"stop_sequence" integer NOT NULL,
	CONSTRAINT "transit_route_pattern_stops_pattern_id_stop_sequence_pk" PRIMARY KEY("pattern_id","stop_sequence")
);
--> statement-breakpoint
CREATE TABLE "transit_route_patterns" (
	"id" text PRIMARY KEY NOT NULL,
	"route_id" text NOT NULL,
	"direction_id" integer NOT NULL,
	"headsign" text NOT NULL,
	"trip_count" integer NOT NULL,
	"is_canonical" boolean DEFAULT false NOT NULL,
	"geometry" geometry(LineString,4326) NOT NULL
);
--> statement-breakpoint
CREATE TABLE "transit_routes" (
	"id" text PRIMARY KEY NOT NULL,
	"agency_id" text NOT NULL,
	"short_name" text NOT NULL,
	"long_name" text NOT NULL,
	"route_type" integer NOT NULL,
	"color" text NOT NULL,
	"text_color" text NOT NULL,
	"imported_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "transit_stops" (
	"id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"location" geometry(Point,4326) NOT NULL
);
--> statement-breakpoint
ALTER TABLE "transit_route_pattern_stops" ADD CONSTRAINT "transit_route_pattern_stops_pattern_id_transit_route_patterns_id_fk" FOREIGN KEY ("pattern_id") REFERENCES "public"."transit_route_patterns"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_route_pattern_stops" ADD CONSTRAINT "transit_route_pattern_stops_stop_id_transit_stops_id_fk" FOREIGN KEY ("stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_route_patterns" ADD CONSTRAINT "transit_route_patterns_route_id_transit_routes_id_fk" FOREIGN KEY ("route_id") REFERENCES "public"."transit_routes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "transit_route_pattern_stops_stop_idx" ON "transit_route_pattern_stops" USING btree ("stop_id");--> statement-breakpoint
CREATE INDEX "transit_route_patterns_geometry_idx" ON "transit_route_patterns" USING gist ("geometry");--> statement-breakpoint
CREATE INDEX "transit_route_patterns_route_idx" ON "transit_route_patterns" USING btree ("route_id");--> statement-breakpoint
CREATE INDEX "transit_stops_location_idx" ON "transit_stops" USING gist ("location");