-- Contract preparation after the ae27 expand migration: old API replicas may
-- still reference these relations during rollout, so keep their empty shapes
-- tracked by Drizzle while removing all obsolete bearer tokens immediately.
--
-- Guarded because the pair is on its way out and a database can legitimately
-- already be without it: migration 0029 drops both tables, and an environment
-- that lost them ahead of the ledger must still be able to replay this file.
DO $contract$
BEGIN
  IF to_regclass('public.notification_live_activities') IS NULL THEN
    RETURN;
  END IF;

  TRUNCATE TABLE "notification_live_activities", "notification_live_activity_start_tokens";

  CREATE INDEX IF NOT EXISTS "notification_live_activities_installation_idx"
    ON "notification_live_activities" USING btree ("installation_id");

  CREATE FUNCTION "discard_legacy_notification_token_write"() RETURNS trigger AS $discard$
  BEGIN
    RETURN NULL;
  END;
  $discard$ LANGUAGE plpgsql;

  CREATE TRIGGER "discard_legacy_live_activity_write"
  BEFORE INSERT OR UPDATE ON "notification_live_activities"
  FOR EACH ROW EXECUTE FUNCTION "discard_legacy_notification_token_write"();

  CREATE TRIGGER "discard_legacy_live_activity_start_write"
  BEFORE INSERT OR UPDATE ON "notification_live_activity_start_tokens"
  FOR EACH ROW EXECUTE FUNCTION "discard_legacy_notification_token_write"();
END;
$contract$;
