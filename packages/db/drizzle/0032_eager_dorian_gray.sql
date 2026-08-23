CREATE TABLE "report_current_votes" (
	"user_id" text NOT NULL,
	"station_id" text NOT NULL,
	"category" text NOT NULL,
	"scope_kind" text NOT NULL,
	"scope_id" text NOT NULL,
	"value" text NOT NULL,
	"observed_at" timestamp with time zone NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "report_current_votes_user_id_station_id_category_scope_kind_scope_id_pk" PRIMARY KEY("user_id","station_id","category","scope_kind","scope_id")
);
--> statement-breakpoint
CREATE TABLE "report_events" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"station_id" text NOT NULL,
	"category" text NOT NULL,
	"scope_kind" text NOT NULL,
	"scope_id" text NOT NULL,
	"value" text NOT NULL,
	"line_id" text,
	"journey_id" text,
	"vehicle_id" text,
	"observed_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "report_current_votes" ADD CONSTRAINT "report_current_votes_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "report_events" ADD CONSTRAINT "report_events_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "report_current_votes_station_observed_idx" ON "report_current_votes" USING btree ("station_id","observed_at");--> statement-breakpoint
CREATE INDEX "report_events_station_observed_idx" ON "report_events" USING btree ("station_id","observed_at");--> statement-breakpoint
CREATE INDEX "report_events_created_idx" ON "report_events" USING btree ("created_at");--> statement-breakpoint
CREATE INDEX "report_events_user_created_idx" ON "report_events" USING btree ("user_id","created_at");