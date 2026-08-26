CREATE TABLE "disruption_history" (
	"id" text PRIMARY KEY NOT NULL,
	"severity" text NOT NULL,
	"cause" text,
	"title" text,
	"message" text,
	"route_ids" text[] DEFAULT '{}'::text[] NOT NULL,
	"periods" jsonb NOT NULL,
	"impacted_sections" jsonb NOT NULL,
	"upstream_updated_at" timestamp with time zone,
	"begins_at" timestamp with time zone,
	"ends_at" timestamp with time zone,
	"first_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	"changed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"content_hash" text NOT NULL
);
--> statement-breakpoint
CREATE INDEX "disruption_history_last_seen_idx" ON "disruption_history" USING btree ("last_seen_at");--> statement-breakpoint
CREATE INDEX "disruption_history_begins_idx" ON "disruption_history" USING btree ("begins_at");--> statement-breakpoint
CREATE INDEX "disruption_history_changed_idx" ON "disruption_history" USING btree ("changed_at");--> statement-breakpoint
CREATE INDEX "disruption_history_routes_idx" ON "disruption_history" USING gin ("route_ids");