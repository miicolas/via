CREATE TABLE "transit_line_directions" (
	"route_id" text NOT NULL,
	"direction_id" integer NOT NULL,
	"label" text NOT NULL,
	CONSTRAINT "transit_line_directions_route_id_direction_id_pk" PRIMARY KEY("route_id","direction_id")
);
--> statement-breakpoint
CREATE TABLE "transit_line_schema_stops" (
	"route_id" text NOT NULL,
	"direction_id" integer NOT NULL,
	"section_index" integer NOT NULL,
	"section_role" text NOT NULL,
	"section_label" text,
	"section_origins" text[] NOT NULL,
	"section_termini" text[] NOT NULL,
	"position" integer NOT NULL,
	"stop_id" text NOT NULL,
	CONSTRAINT "transit_line_schema_stops_route_id_direction_id_section_index_position_pk" PRIMARY KEY("route_id","direction_id","section_index","position")
);
--> statement-breakpoint
ALTER TABLE "transit_line_directions" ADD CONSTRAINT "transit_line_directions_route_id_transit_routes_id_fk" FOREIGN KEY ("route_id") REFERENCES "public"."transit_routes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_line_schema_stops" ADD CONSTRAINT "transit_line_schema_stops_route_id_transit_routes_id_fk" FOREIGN KEY ("route_id") REFERENCES "public"."transit_routes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_line_schema_stops" ADD CONSTRAINT "transit_line_schema_stops_stop_id_transit_stops_id_fk" FOREIGN KEY ("stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "transit_line_schema_stops_route_idx" ON "transit_line_schema_stops" USING btree ("route_id");