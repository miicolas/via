CREATE TABLE "transit_service_dates" (
	"service_id" text NOT NULL,
	"date" date NOT NULL,
	CONSTRAINT "transit_service_dates_service_id_date_pk" PRIMARY KEY("service_id","date")
);
--> statement-breakpoint
CREATE TABLE "transit_stop_departures" (
	"stop_id" text NOT NULL,
	"route_id" text NOT NULL,
	"direction_id" integer NOT NULL,
	"headsign" text NOT NULL,
	"service_id" text NOT NULL,
	"departure_seconds" integer NOT NULL
);
--> statement-breakpoint
ALTER TABLE "transit_stop_departures" ADD CONSTRAINT "transit_stop_departures_stop_id_transit_stops_id_fk" FOREIGN KEY ("stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transit_stop_departures" ADD CONSTRAINT "transit_stop_departures_route_id_transit_routes_id_fk" FOREIGN KEY ("route_id") REFERENCES "public"."transit_routes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "transit_stop_departures_lookup_idx" ON "transit_stop_departures" USING btree ("stop_id","service_id","departure_seconds");