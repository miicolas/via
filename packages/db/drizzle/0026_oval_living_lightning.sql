-- Contract preparation after the ae27 expand migration: old API replicas may
-- still reference these relations during rollout, so keep their empty shapes
-- tracked by Drizzle while removing all obsolete bearer tokens immediately.
TRUNCATE TABLE "notification_live_activities", "notification_live_activity_start_tokens";--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "notification_live_activities_installation_idx" ON "notification_live_activities" USING btree ("installation_id");--> statement-breakpoint
CREATE FUNCTION "discard_legacy_notification_token_write"() RETURNS trigger AS $$
BEGIN
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;--> statement-breakpoint
CREATE TRIGGER "discard_legacy_live_activity_write"
BEFORE INSERT OR UPDATE ON "notification_live_activities"
FOR EACH ROW EXECUTE FUNCTION "discard_legacy_notification_token_write"();--> statement-breakpoint
CREATE TRIGGER "discard_legacy_live_activity_start_write"
BEFORE INSERT OR UPDATE ON "notification_live_activity_start_tokens"
FOR EACH ROW EXECUTE FUNCTION "discard_legacy_notification_token_write"();
