ALTER TABLE "boarding_positions" ADD COLUMN "station_stop_id" text;--> statement-breakpoint
ALTER TABLE "boarding_positions" ADD COLUMN "direction_id" integer;--> statement-breakpoint
ALTER TABLE "boarding_positions" ADD CONSTRAINT "boarding_positions_station_stop_id_transit_stops_id_fk" FOREIGN KEY ("station_stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "boarding_positions_station_route_idx" ON "boarding_positions" USING btree ("station_stop_id","route_id","direction_id");