CREATE TABLE "boarding_positions" (
	"from_quay_id" text NOT NULL,
	"target_id" text NOT NULL,
	"target_kind" text NOT NULL,
	"route_id" text NOT NULL,
	"car" integer NOT NULL,
	"car_count" integer NOT NULL,
	"zone" text NOT NULL,
	"equipment" text,
	"source" text NOT NULL,
	"source_updated_at" timestamp with time zone,
	"imported_at" timestamp with time zone NOT NULL,
	CONSTRAINT "boarding_positions_from_quay_id_target_id_pk" PRIMARY KEY("from_quay_id","target_id"),
	CONSTRAINT "boarding_positions_car_check" CHECK ("boarding_positions"."car" BETWEEN 1 AND "boarding_positions"."car_count")
);
--> statement-breakpoint
CREATE TABLE "station_exits" (
	"id" text PRIMARY KEY NOT NULL,
	"stop_id" text NOT NULL,
	"name" text NOT NULL,
	"number" integer,
	"detail" text,
	"location" geometry(Point,4326) NOT NULL,
	"source" text NOT NULL,
	"source_ref" text NOT NULL,
	"source_updated_at" timestamp with time zone,
	"imported_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
ALTER TABLE "station_exits" ADD CONSTRAINT "station_exits_stop_id_transit_stops_id_fk" FOREIGN KEY ("stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "station_exits_stop_idx" ON "station_exits" USING btree ("stop_id");--> statement-breakpoint
CREATE INDEX "station_exits_location_idx" ON "station_exits" USING gist ("location");