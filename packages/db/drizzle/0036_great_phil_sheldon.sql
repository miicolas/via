CREATE TABLE "station_elevators" (
	"id" text PRIMARY KEY NOT NULL,
	"stop_id" text NOT NULL,
	"private_id" text,
	"situation" text,
	"direction" text,
	"status" text NOT NULL,
	"reason" text,
	"state_updated_at" timestamp with time zone,
	"source" text NOT NULL,
	"imported_at" timestamp with time zone NOT NULL,
	CONSTRAINT "station_elevators_status_check" CHECK ("station_elevators"."status" IN ('available', 'notavailable', 'unknown')),
	CONSTRAINT "station_elevators_reason_check" CHECK ("station_elevators"."reason" IS NULL OR "station_elevators"."reason" IN ('liftFailure', 'closedForMaintenance', 'undefinedEquipmentProblem'))
);
--> statement-breakpoint
ALTER TABLE "station_facts" DROP CONSTRAINT "station_facts_condition_check";--> statement-breakpoint
ALTER TABLE "station_elevators" ADD CONSTRAINT "station_elevators_stop_id_transit_stops_id_fk" FOREIGN KEY ("stop_id") REFERENCES "public"."transit_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "station_elevators_stop_idx" ON "station_elevators" USING btree ("stop_id");--> statement-breakpoint
CREATE INDEX "station_elevators_status_idx" ON "station_elevators" USING btree ("status");--> statement-breakpoint
ALTER TABLE "station_facts" ADD CONSTRAINT "station_facts_condition_check" CHECK ((
        "station_facts"."kind" = 'accessibility'
        AND "station_facts"."condition" IN ('autonomous', 'staffAssistance', 'reservationRequired')
      ) OR (
        "station_facts"."kind" = 'toilets'
        AND "station_facts"."condition" = 'available'
      ));