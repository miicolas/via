CREATE TABLE "notification_devices" (
	"installation_id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"device_token" text NOT NULL,
	"bundle_id" text NOT NULL,
	"environment" text NOT NULL,
	"app_version" text,
	"os_version" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notification_journey_subscriptions" (
	"installation_id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"journey_id" text NOT NULL,
	"route_ids" text[] NOT NULL,
	"starts_at" timestamp with time zone NOT NULL,
	"ends_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notification_live_activities" (
	"activity_id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"installation_id" text NOT NULL,
	"journey_id" text NOT NULL,
	"activity_token" text NOT NULL,
	"bundle_id" text NOT NULL,
	"environment" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notification_live_activity_start_tokens" (
	"installation_id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"push_to_start_token" text NOT NULL,
	"bundle_id" text NOT NULL,
	"environment" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "notification_devices" ADD CONSTRAINT "notification_devices_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_journey_subscriptions" ADD CONSTRAINT "notification_journey_subscriptions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_live_activities" ADD CONSTRAINT "notification_live_activities_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notification_live_activity_start_tokens" ADD CONSTRAINT "notification_live_activity_start_tokens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "notification_devices_token_uidx" ON "notification_devices" USING btree ("bundle_id","environment","device_token");--> statement-breakpoint
CREATE INDEX "notification_devices_user_idx" ON "notification_devices" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "notification_journey_subscriptions_user_idx" ON "notification_journey_subscriptions" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "notification_journey_subscriptions_journey_idx" ON "notification_journey_subscriptions" USING btree ("journey_id");--> statement-breakpoint
CREATE INDEX "notification_journey_subscriptions_ends_idx" ON "notification_journey_subscriptions" USING btree ("ends_at");--> statement-breakpoint
CREATE UNIQUE INDEX "notification_live_activities_token_uidx" ON "notification_live_activities" USING btree ("bundle_id","environment","activity_token");--> statement-breakpoint
CREATE INDEX "notification_live_activities_user_idx" ON "notification_live_activities" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "notification_live_activities_journey_idx" ON "notification_live_activities" USING btree ("journey_id");--> statement-breakpoint
CREATE UNIQUE INDEX "notification_live_activity_start_tokens_token_uidx" ON "notification_live_activity_start_tokens" USING btree ("bundle_id","environment","push_to_start_token");--> statement-breakpoint
CREATE INDEX "notification_live_activity_start_tokens_user_idx" ON "notification_live_activity_start_tokens" USING btree ("user_id");