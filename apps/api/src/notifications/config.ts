/** Operational notification values are code-owned; they are not product preferences. */
export const NOTIFICATION_SCHEDULER_ENABLED = true;
export const NOTIFICATION_ALERTS_ENABLED = true;
export const NOTIFICATION_DISPATCH_POLL_SECONDS = 20;
export const NOTIFICATION_MATERIALIZE_POLL_SECONDS = 15 * 60;
export const NOTIFICATION_ALERT_POLL_SECONDS = 120;
export const NOTIFICATION_DISRUPTION_POLL_SECONDS = 120;
export const NOTIFICATION_OCCURRENCE_BATCH = 200;
export const NOTIFICATION_STALE_MINUTES = 10;
export const NOTIFICATION_INBOX_RETENTION_DAYS = 30;
export const NOTIFICATION_OCCURRENCE_RETENTION_DAYS = 7;
export const NOTIFICATION_CATEGORY_DAILY_CAPS = {
  journey: undefined,
  commute: undefined,
  line: 6,
  station: 4,
  digest: 1,
  recommendation: 2,
} as const;
