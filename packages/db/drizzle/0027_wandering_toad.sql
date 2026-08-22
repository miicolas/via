CREATE TABLE "notification_alert_subscriptions" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"topic_kind" text NOT NULL,
	"topic_id" text NOT NULL,
	"label" text NOT NULL,
	"days_of_week" integer[] DEFAULT '{}'::integer[] NOT NULL,
	"windows" jsonb NOT NULL,
	"minimum_severity" text DEFAULT 'attention' NOT NULL,
	"enabled" boolean DEFAULT true NOT NULL,
	"saved_at" timestamp with time zone NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "notification_inbox" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"occurrence_id" text,
	"category" text NOT NULL,
	"title" text NOT NULL,
	"body" text NOT NULL,
	"deep_link" text,
	"topic_kind" text,
	"topic_id" text,
	"severity" text,
	"drop_reason" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"read_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "notification_mutes" (
	"user_id" text NOT NULL,
	"scope" text NOT NULL,
	"key" text NOT NULL,
	"muted_until" timestamp with time zone,
	CONSTRAINT "notification_mutes_user_id_scope_key_pk" PRIMARY KEY("user_id","scope","key")
);
--> statement-breakpoint
CREATE TABLE "notification_occurrences" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"schedule_id" text,
	"category" text NOT NULL,
	"schedule_revision" integer DEFAULT 1 NOT NULL,
	"due_at" timestamp with time zone NOT NULL,
	"state" text DEFAULT 'pending' NOT NULL,
	"drop_reason" text,
	"attempts" integer DEFAULT 0 NOT NULL,
	"lease_until" timestamp with time zone,
	"dedupe_key" text NOT NULL,
	"payload" jsonb NOT NULL,
	"delivery_shard" integer GENERATED ALWAYS AS (mod(hashtextextended(user_id, 0) & 9223372036854775807, 64)) STORED,
	CONSTRAINT "notification_occurrences_dedupe_key_unique" UNIQUE("dedupe_key")
);
--> statement-breakpoint
CREATE TABLE "notification_preferences" (
	"user_id" text PRIMARY KEY NOT NULL,
	"enabled" boolean DEFAULT true NOT NULL,
	"time_zone" text DEFAULT 'Europe/Paris' NOT NULL,
	"quiet_hours_start_minute" integer,
	"quiet_hours_end_minute" integer,
	"muted_on_weekends" boolean DEFAULT false NOT NULL,
	"muted_on_holidays" boolean DEFAULT false NOT NULL,
	"minimum_severity" text DEFAULT 'attention' NOT NULL,
	"daily_cap" integer DEFAULT 20 NOT NULL,
	"categories" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "notification_preferences_time_zone_check" CHECK ("notification_preferences"."time_zone" = 'Europe/Paris')
);
--> statement-breakpoint
CREATE TABLE "notification_schedules" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"kind" text NOT NULL,
	"label" text NOT NULL,
	"revision" integer DEFAULT 1 NOT NULL,
	"origin" jsonb,
	"destination" jsonb,
	"route_ids" text[] DEFAULT '{}'::text[] NOT NULL,
	"days_of_week" integer[] DEFAULT '{}'::integer[] NOT NULL,
	"departure_minute" integer NOT NULL,
	"lead_minutes" integer DEFAULT 10 NOT NULL,
	"skip_holidays" boolean DEFAULT false NOT NULL,
	"enabled" boolean DEFAULT true NOT NULL,
	"paused_until" timestamp with time zone,
	"time_zone" text DEFAULT 'Europe/Paris' NOT NULL,
	"saved_at" timestamp with time zone NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "notification_schedules_time_zone_check" CHECK ("notification_schedules"."time_zone" = 'Europe/Paris')
);
--> statement-breakpoint
ALTER TABLE "notification_alert_subscriptions" ADD CONSTRAINT "notification_alert_subscriptions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_inbox" ADD CONSTRAINT "notification_inbox_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_inbox" ADD CONSTRAINT "notification_inbox_occurrence_id_notification_occurrences_id_fk" FOREIGN KEY ("occurrence_id") REFERENCES "public"."notification_occurrences"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_mutes" ADD CONSTRAINT "notification_mutes_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_occurrences" ADD CONSTRAINT "notification_occurrences_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_occurrences" ADD CONSTRAINT "notification_occurrences_schedule_id_notification_schedules_id_fk" FOREIGN KEY ("schedule_id") REFERENCES "public"."notification_schedules"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_preferences" ADD CONSTRAINT "notification_preferences_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_schedules" ADD CONSTRAINT "notification_schedules_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "notification_alert_subscriptions_user_idx" ON "notification_alert_subscriptions" USING btree ("user_id","id");--> statement-breakpoint
CREATE INDEX "notification_alert_subscriptions_topic_idx" ON "notification_alert_subscriptions" USING btree ("topic_kind","topic_id") WHERE "enabled" = true AND "deleted_at" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "notification_alert_subscriptions_user_topic_uidx" ON "notification_alert_subscriptions" USING btree ("user_id","topic_kind","topic_id") WHERE "deleted_at" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "notification_inbox_user_occurrence_uidx" ON "notification_inbox" USING btree ("user_id","occurrence_id") WHERE "occurrence_id" IS NOT NULL;--> statement-breakpoint
CREATE INDEX "notification_inbox_cursor_idx" ON "notification_inbox" USING btree ("user_id","created_at","id");--> statement-breakpoint
CREATE INDEX "notification_inbox_unread_idx" ON "notification_inbox" USING btree ("user_id") WHERE "read_at" IS NULL;--> statement-breakpoint
CREATE INDEX "notification_mutes_active_idx" ON "notification_mutes" USING btree ("user_id","scope","key");--> statement-breakpoint
CREATE INDEX "notification_occurrences_pending_idx" ON "notification_occurrences" USING btree ("due_at","id") WHERE "state" = 'pending';--> statement-breakpoint
CREATE INDEX "notification_occurrences_sending_idx" ON "notification_occurrences" USING btree ("lease_until") WHERE "state" = 'sending';--> statement-breakpoint
CREATE INDEX "notification_occurrences_user_idx" ON "notification_occurrences" USING btree ("user_id","due_at");--> statement-breakpoint
CREATE INDEX "notification_schedules_user_idx" ON "notification_schedules" USING btree ("user_id","id");--> statement-breakpoint
CREATE INDEX "notification_schedules_active_idx" ON "notification_schedules" USING btree ("user_id","enabled") WHERE "enabled" = true AND "deleted_at" IS NULL;--> statement-breakpoint
COMMENT ON TABLE "notification_occurrences" IS 'File durable des occurrences, claimée avec FOR UPDATE SKIP LOCKED.';--> statement-breakpoint
COMMENT ON COLUMN "notification_occurrences"."dedupe_key" IS 'Clé locale scheduleId:date:minute, stable across DST.';--> statement-breakpoint
COMMENT ON TABLE "notification_inbox" IS 'Registre durable écrit avant chaque envoi APNs.';
