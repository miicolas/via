DROP INDEX "notification_alert_subscriptions_topic_idx";--> statement-breakpoint
DROP INDEX "notification_alert_subscriptions_user_topic_uidx";--> statement-breakpoint
DROP INDEX "notification_inbox_user_occurrence_uidx";--> statement-breakpoint
DROP INDEX "notification_inbox_unread_idx";--> statement-breakpoint
DROP INDEX "notification_occurrences_pending_idx";--> statement-breakpoint
DROP INDEX "notification_occurrences_sending_idx";--> statement-breakpoint
DROP INDEX "notification_schedules_active_idx";--> statement-breakpoint
CREATE INDEX "notification_alert_subscriptions_topic_idx" ON "notification_alert_subscriptions" USING btree ("topic_kind","topic_id") WHERE "notification_alert_subscriptions"."enabled" = true AND "notification_alert_subscriptions"."deleted_at" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "notification_alert_subscriptions_user_topic_uidx" ON "notification_alert_subscriptions" USING btree ("user_id","topic_kind","topic_id") WHERE "notification_alert_subscriptions"."deleted_at" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "notification_inbox_user_occurrence_uidx" ON "notification_inbox" USING btree ("user_id","occurrence_id") WHERE "notification_inbox"."occurrence_id" IS NOT NULL;--> statement-breakpoint
CREATE INDEX "notification_inbox_unread_idx" ON "notification_inbox" USING btree ("user_id") WHERE "notification_inbox"."read_at" IS NULL;--> statement-breakpoint
CREATE INDEX "notification_occurrences_pending_idx" ON "notification_occurrences" USING btree ("due_at","id") WHERE "notification_occurrences"."state" = 'pending';--> statement-breakpoint
CREATE INDEX "notification_occurrences_sending_idx" ON "notification_occurrences" USING btree ("lease_until") WHERE "notification_occurrences"."state" = 'sending';--> statement-breakpoint
CREATE INDEX "notification_schedules_active_idx" ON "notification_schedules" USING btree ("user_id","enabled") WHERE "notification_schedules"."enabled" = true AND "notification_schedules"."deleted_at" IS NULL;