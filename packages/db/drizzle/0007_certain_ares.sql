CREATE TABLE "transit_shapes" (
	"id" text PRIMARY KEY NOT NULL,
	"geometry" geometry(LineString,4326)
);
--> statement-breakpoint
CREATE TABLE "transit_stop_routes" (
	"stop_id" text NOT NULL,
	"route_id" text NOT NULL,
	CONSTRAINT "transit_stop_routes_stop_id_route_id_pk" PRIMARY KEY("stop_id","route_id")
);
--> statement-breakpoint
CREATE TABLE "transit_transfers" (
	"from_stop_id" text NOT NULL,
	"to_stop_id" text NOT NULL,
	"min_transfer_seconds" integer NOT NULL,
	CONSTRAINT "transit_transfers_from_stop_id_to_stop_id_pk" PRIMARY KEY("from_stop_id","to_stop_id")
);
--> statement-breakpoint
CREATE TABLE "transit_trip_stop_times" (
	"trip_id" text NOT NULL,
	"stop_id" text NOT NULL,
	"stop_sequence" integer NOT NULL,
	"arrival_seconds" integer NOT NULL,
	"departure_seconds" integer NOT NULL,
	CONSTRAINT "transit_trip_stop_times_trip_id_stop_sequence_pk" PRIMARY KEY("trip_id","stop_sequence")
);
--> statement-breakpoint
CREATE TABLE "transit_trips" (
	"id" text PRIMARY KEY NOT NULL,
	"route_id" text NOT NULL,
	"service_id" text NOT NULL,
	"direction_id" integer NOT NULL,
	"headsign" text NOT NULL,
	"shape_id" text
);
--> statement-breakpoint
ALTER TABLE "transit_stop_routes" ADD CONSTRAINT "transit_stop_routes_stop_id_transit_stops_id_fk" FOREIGN KEY ("stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_stop_routes" ADD CONSTRAINT "transit_stop_routes_route_id_transit_routes_id_fk" FOREIGN KEY ("route_id") REFERENCES "public"."transit_routes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_transfers" ADD CONSTRAINT "transit_transfers_from_stop_id_transit_stops_id_fk" FOREIGN KEY ("from_stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_transfers" ADD CONSTRAINT "transit_transfers_to_stop_id_transit_stops_id_fk" FOREIGN KEY ("to_stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" ADD CONSTRAINT "transit_trip_stop_times_trip_id_transit_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."transit_trips"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_trip_stop_times" ADD CONSTRAINT "transit_trip_stop_times_stop_id_transit_stops_id_fk" FOREIGN KEY ("stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_trips" ADD CONSTRAINT "transit_trips_route_id_transit_routes_id_fk" FOREIGN KEY ("route_id") REFERENCES "public"."transit_routes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "transit_transfers_from_idx" ON "transit_transfers" USING btree ("from_stop_id");--> statement-breakpoint
CREATE INDEX "transit_trip_stop_times_stop_departure_idx" ON "transit_trip_stop_times" USING btree ("stop_id","departure_seconds");--> statement-breakpoint
CREATE INDEX "transit_trip_stop_times_trip_idx" ON "transit_trip_stop_times" USING btree ("trip_id","stop_sequence");--> statement-breakpoint
CREATE INDEX "transit_trips_service_route_idx" ON "transit_trips" USING btree ("service_id","route_id");--> statement-breakpoint
CREATE INDEX "transit_trips_shape_idx" ON "transit_trips" USING btree ("shape_id");