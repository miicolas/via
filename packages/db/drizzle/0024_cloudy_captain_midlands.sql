ALTER TABLE "notification_journey_subscriptions" ADD COLUMN "route_windows" jsonb;--> statement-breakpoint
UPDATE "notification_journey_subscriptions"
SET "route_windows" = COALESCE(
  (
    SELECT jsonb_agg(
      jsonb_build_object(
        'routeId', "route_id",
        'startsAt', floor(extract(epoch from "notification_journey_subscriptions"."starts_at")),
        'endsAt', floor(extract(epoch from "notification_journey_subscriptions"."ends_at"))
      )
    )
    FROM unnest("notification_journey_subscriptions"."route_ids") AS "route_id"
  ),
  '[]'::jsonb
);--> statement-breakpoint
ALTER TABLE "notification_journey_subscriptions" ALTER COLUMN "route_windows" SET DEFAULT '[]'::jsonb;--> statement-breakpoint
ALTER TABLE "notification_journey_subscriptions" ALTER COLUMN "route_windows" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "notification_journey_subscriptions" ALTER COLUMN "route_ids" SET DEFAULT '{}'::text[];--> statement-breakpoint
CREATE FUNCTION "sync_legacy_notification_route_windows"() RETURNS trigger AS $$
BEGIN
  NEW.route_windows = COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'routeId', route_id,
          'startsAt', floor(extract(epoch from NEW.starts_at)),
          'endsAt', floor(extract(epoch from NEW.ends_at))
        )
      )
      FROM unnest(NEW.route_ids) AS route_id
    ),
    '[]'::jsonb
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;--> statement-breakpoint
CREATE TRIGGER "notification_route_ids_compat_trigger"
BEFORE INSERT OR UPDATE OF "route_ids" ON "notification_journey_subscriptions"
FOR EACH ROW EXECUTE FUNCTION "sync_legacy_notification_route_windows"();--> statement-breakpoint
CREATE UNIQUE INDEX "notification_devices_installation_user_uidx" ON "notification_devices" USING btree ("installation_id","user_id");--> statement-breakpoint
ALTER TABLE "notification_journey_subscriptions" ADD CONSTRAINT "notification_journey_subscriptions_installation_user_fk" FOREIGN KEY ("installation_id","user_id") REFERENCES "public"."notification_devices"("installation_id","user_id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "notification_journey_subscriptions_starts_idx" ON "notification_journey_subscriptions" USING btree ("starts_at");
