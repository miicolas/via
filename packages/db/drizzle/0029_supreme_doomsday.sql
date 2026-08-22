-- End of the ae27 rollout window. No replica reads these ActivityKit tokens any
-- more and 0026 already emptied them, so the physical shapes go too — along with
-- the trigger function 0026 installed to swallow writes from replicas that no
-- longer exist.
--
-- IF EXISTS because a database can have lost the pair ahead of this file: what
-- this migration guarantees is the absence, not the drop.
DROP TABLE IF EXISTS "notification_live_activities" CASCADE;--> statement-breakpoint
DROP TABLE IF EXISTS "notification_live_activity_start_tokens" CASCADE;--> statement-breakpoint
DROP FUNCTION IF EXISTS "discard_legacy_notification_token_write"();
